"""Build/verify a selected handoff ZIP using only the standard library.

Explicit selection excludes history, credentials and caches. Path filters are
not a complete secret scanner; review selected files before sharing.
"""
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tempfile
from urllib.parse import quote, unquote, urlsplit
import zipfile


BLOCKED = {".git", ".aws", ".ssh", ".codex", ".fvm", ".dart_tool",
           ".gradle", ".idea", "__pycache__", "node_modules", "build",
           ".ds_store", "local.properties", "settings.local.json",
           "key.properties", "keystore.properties", "credentials.json", "secrets.json",
           ".venv", ".cache", "dist"}
PRIVATE = re.compile(rb"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")
RESERVED = {"CON", "PRN", "AUX", "NUL"} | {f"{p}{n}" for p in ("COM", "LPT") for n in range(1, 10)}


def portable(name):
    if not isinstance(name, str) or not name or "\\" in name:
        raise ValueError("use nonempty relative paths with / separators")
    path = PurePosixPath(name)
    if path.is_absolute() or str(path) != name or name == "." or ".." in path.parts:
        raise ValueError(f"unsafe path: {name}")
    for part in path.parts:
        if (part.endswith((".", " ")) or any(ord(c) < 32 or c in '<>:"|?*' for c in part)
                or part.split(".")[0].upper() in RESERVED):
            raise ValueError(f"nonportable filename: {name}")
    return name


def blocked(name):
    return any(p.lower() in BLOCKED or p.lower().startswith((".env", ".dev.vars"))
               or p.lower().endswith((".jks", ".keystore", ".p12", ".pfx", ".pem", ".p8", ".key", ".ppk", ".zip"))
               or p.lower().startswith(("id_rsa", "id_ed25519", "service-account"))
               for p in PurePosixPath(name).parts)


def label(value):
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", value):
        raise ValueError("use a short filename-safe revision such as checkpoint-01")
    return value


def collect(root, plan):
    if set(plan) - {"label", "entrypoint", "include", "exclude"}:
        raise ValueError("unknown plan field")
    label(plan["label"])
    entry = portable(plan["entrypoint"])
    includes, excludes = plan["include"], plan.get("exclude", [])
    if not isinstance(includes, list) or not includes or not isinstance(excludes, list):
        raise ValueError("include must be a nonempty list; exclude must be a list")
    excludes = [portable(x) for x in excludes]
    selected, skipped = {}, set()

    def visit(path):
        relative = portable(path.relative_to(root).as_posix())
        if blocked(relative) or any(relative == x or relative.startswith(x + "/") for x in excludes):
            skipped.add(relative)
            return
        if any(p.is_symlink() for p in (path, *path.parents)):
            raise ValueError(f"symlink is not packaged: {relative}")
        if not path.resolve().is_relative_to(root):
            raise ValueError(f"path leaves project: {relative}")
        if path.is_dir():
            for child in sorted(path.iterdir()):
                visit(child)
        elif path.is_file():
            selected[relative] = path
        else:
            raise ValueError(f"missing or unsupported selected file: {relative}")

    for name in includes:
        visit(root / portable(name))
    if entry not in selected:
        raise ValueError("entrypoint must be an included handoff document")
    if len({x.casefold() for x in selected}) != len(selected):
        raise ValueError("case-insensitive filename collision")
    fence = chr(96) * 3
    for name, path in selected.items():
        if not name.endswith(".md"):
            continue
        prose = re.sub(r"^" + fence + r"[^\n]*\n.*?^" + fence + r"[^\n]*$", "",
                       path.read_text(encoding="utf-8"), flags=re.M | re.S)
        for target in re.findall(r"\]\(([^)]+)\)", prose):
            url = urlsplit(target.strip("<>"))
            if url.scheme or url.netloc or not url.path:
                continue
            dest = (path.parent / unquote(url.path)).resolve()
            if not dest.is_relative_to(root):
                raise ValueError(f"link leaves project: {name}")
            linked = dest.relative_to(root).as_posix()
            if linked not in selected and not any(x.startswith(linked + "/") for x in selected):
                raise ValueError(f"linked file not included: {name} -> {target}")
    return dict(sorted(selected.items())), sorted(skipped)


def git_context(root):
    def read(*args):
        try:
            return subprocess.check_output(["git", "-C", str(root), *args],
                                           stderr=subprocess.DEVNULL, text=True, encoding="utf-8", errors="replace").strip()
        except (OSError, subprocess.CalledProcessError):
            return None
    top = read("rev-parse", "--show-toplevel")
    if top is None or Path(top).resolve() != root:
        return {"commit": None, "branch": None, "working_tree_dirty": None}
    status = read("status", "--porcelain")
    return {"commit": read("rev-parse", "HEAD"), "branch": read("branch", "--show-current"),
            "working_tree_dirty": None if status is None else bool(status)}


def fingerprint(path):
    s = path.stat()
    return s.st_size, s.st_mtime_ns, s.st_mode


def stream_hash(stream):
    digest, size = hashlib.sha256(), 0
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        digest.update(chunk)
        size += len(chunk)
    return digest.hexdigest(), size


def verify(output):
    with zipfile.ZipFile(output) as archive:
        names = archive.namelist()
        if not {"START_HERE.md", "MANIFEST.json"} <= set(names):
            raise ValueError("missing starter or manifest")
        for name in names:
            portable(name)
            if name not in {"START_HERE.md", "MANIFEST.json"} and not name.startswith("project/"):
                raise ValueError("unexpected archive root")
        if len(set(x.casefold() for x in names)) != len(names):
            raise ValueError("duplicate/case-insensitive ZIP member")
        if any(stat.S_ISLNK(x.external_attr >> 16) for x in archive.infolist()):
            raise ValueError("ZIP contains a symlink")
        manifest = json.loads(archive.read("MANIFEST.json"))
        if manifest["schema_version"] != 1:
            raise ValueError("unsupported manifest schema")
        label(manifest["label"])
        records = manifest["files"]
        if set(names) != {"MANIFEST.json"} | {x["path"] for x in records} or len(records) != len(names) - 1:
            raise ValueError("manifest/file list mismatch")
        if "project/" + portable(manifest["entrypoint"]) not in names:
            raise ValueError("missing handoff entrypoint")
        for record in records:
            with archive.open(record["path"]) as stream:
                digest, size = stream_hash(stream)
            if digest != record["sha256"] or size != record["size"]:
                raise ValueError(f"content hash/size mismatch: {record['path']}")
    return manifest


def build(root, plan, output):
    root, output = root.resolve(), output.absolute()
    if output.suffix.lower() != ".zip" or output.exists():
        raise ValueError("output must be a new .zip file; choose a new revision")
    selected, skipped = collect(root, plan)
    before = {name: fingerprint(path) for name, path in selected.items()}
    context = git_context(root)
    dirty_text = {True: "あり", False: "なし", None: "未取得"}[context["working_tree_dirty"]]
    manifest = {"schema_version": 1, "label": plan["label"],
                "created_at_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
                "entrypoint": plan["entrypoint"], "source": context,
                "excluded": skipped, "files": []}
    start = (f"# {plan['label']} — 共有スナップショット\n\n"
             f"最初に [引き継ぎ資料](project/{quote(plan['entrypoint'], safe='/')}) を読んでください。\n\n"
             "プレゼン担当は資料・画面・素材から開始できます。アプリの起動は必須ではありません。\n"
             "Claude Code/Codexで作業する場合は project フォルダを開き、READMEと共通指示を確認します。\n"
             "開発の統合には資料に記載したGitHubと基準コミットを使います。このZIPにGit履歴はありません。\n"
             "既存の作業フォルダへZIP全体を上書きせず、担当ブランチで差分を確認してください。\n\n"
             f"基準コミット: {context['commit'] or '取得できず・資料で確認'}\n"
             f"未コミット変更の有無: {dirty_text}\n"
             "実際の各ファイルの内容は MANIFEST.json のハッシュで識別します。\n")
    output.parent.mkdir(parents=True, exist_ok=True)
    created = False
    try:
        with zipfile.ZipFile(output, "x", compression=zipfile.ZIP_DEFLATED) as archive:
            created = True
            for name, path in selected.items():
                info = zipfile.ZipInfo("project/" + name)
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = (stat.S_IFREG | (path.stat().st_mode & 0o777)) << 16
                digest, size, tail = hashlib.sha256(), 0, b""
                with path.open("rb") as source, archive.open(info, "w") as target:
                    for chunk in iter(lambda: source.read(1024 * 1024), b""):
                        if PRIVATE.search(tail + chunk):
                            raise ValueError(f"private key content detected: {name}")
                        tail = chunk[-100:]
                        digest.update(chunk)
                        size += len(chunk)
                        target.write(chunk)
                manifest["files"].append({"path": info.filename, "size": size, "sha256": digest.hexdigest()})
            data = start.encode("utf-8")
            archive.writestr("START_HERE.md", data)
            manifest["files"].append({"path": "START_HERE.md", "size": len(data),
                                      "sha256": hashlib.sha256(data).hexdigest()})
            archive.writestr("MANIFEST.json", json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
        if any(fingerprint(path) != before[name] for name, path in selected.items()) or git_context(root) != context:
            raise ValueError("source changed during packaging; retry at a stable checkpoint")
        verify(output)
    except Exception:
        if created:
            output.unlink()
        raise
    return manifest


def self_test():
    with tempfile.TemporaryDirectory(prefix="spajam-zip-test-") as temporary:
        base, root = Path(temporary), Path(temporary) / "project"
        (root / "docs").mkdir(parents=True)
        (root / "assets").mkdir()
        (root / "scripts").mkdir()
        (root / "scripts/build_package.py").write_bytes(Path(__file__).read_bytes())
        (root / "README.md").write_text("[Guide](docs/handoff.md)\n", encoding="utf-8")
        guide = root / "docs/handoff.md"
        guide.write_text("架空試行。未実装です。[画面](../assets/screen.svg)\n", encoding="utf-8")
        (root / "assets/screen.svg").write_text("<svg xmlns='http://www.w3.org/2000/svg'/>", encoding="utf-8")
        (root / ".env").write_text("FAKE_TOKEN=fixture-only\n")
        (root / "build").mkdir()
        (root / "build/cache").write_text("fixture")
        (root / "android").mkdir()
        (root / "android/key.properties").write_text("fixture-only; no real credentials\n")
        plan = {"label": "trial-01", "entrypoint": "docs/handoff.md",
                "include": ["README.md", "docs", "assets", "scripts", ".env", "build", "android"]}
        output = base / "trial.zip"
        build(root, plan, output)
        result = verify(output)
        assert result["source"]["commit"] is None
        assert {".env", "build", "android/key.properties"} <= set(result["excluded"])
        assert "project/assets/screen.svg" in {x["path"] for x in result["files"]}
        assert "project/scripts/build_package.py" in {x["path"] for x in result["files"]}
        print("PASS: build including packager, exclusions, source identity and hashes")

        def rejected(title, fragment, action):
            try:
                action()
            except (ValueError, OSError) as error:
                assert fragment in str(error), str(error)
                print("PASS:", title)
            else:
                raise AssertionError(title)

        original = output.read_bytes()
        rejected("existing ZIP preserved", "new .zip", lambda: build(root, plan, output))
        assert output.read_bytes() == original
        guide.write_text(guide.read_text(encoding="utf-8") + "更新版。\n", encoding="utf-8")
        second = base / "trial-02.zip"
        build(root, dict(plan, label="trial-02"), second)
        records = {x["path"]: x for x in verify(second)["files"]}
        assert records["project/docs/handoff.md"]["sha256"] == hashlib.sha256(guide.read_bytes()).hexdigest()
        assert records["project/docs/handoff.md"] != next(x for x in result["files"] if x["path"].endswith("/handoff.md"))
        assert output.read_bytes() == original
        print("PASS: new revision captures changed document and preserves old ZIP")
        guide.write_text("[missing](not-in-package.png)\n", encoding="utf-8")
        rejected("missing linked asset rejected", "linked file not included",
                 lambda: build(root, plan, base / "missing.zip"))
        guide.write_text("架空試行。\n", encoding="utf-8")
        rejected("outside selection rejected", "unsafe path",
                 lambda: build(root, dict(plan, include=["../outside"]), base / "outside.zip"))
        fake_header = "-" * 5 + "BEGIN PRIVATE KEY" + "-" * 5
        (root / "assets/key.txt").write_text(fake_header + "\nfixture-only\n")
        failed = base / "private.zip"
        rejected("private key and incomplete output rejected", "private key",
                 lambda: build(root, plan, failed))
        assert not failed.exists()
        (root / "assets/key.txt").unlink()
        link = root / "assets/outside"
        try:
            link.symlink_to(base, target_is_directory=True)
        except OSError:
            print("SKIP: symlink test (OS permission unavailable)")
        else:
            rejected("symlink traversal rejected", "symlink",
                     lambda: build(root, plan, base / "symlink.zip"))
            link.unlink()
        for name, extra, fragment in [
                ("tampered", None, "content hash/size"),
                ("starter", None, "missing starter"),
                ("traversal", "../escape.txt", "unsafe path"),
                ("case", "project/readme.md", "case-insensitive")]:
            altered = base / (name + ".zip")
            with zipfile.ZipFile(output) as source, zipfile.ZipFile(altered, "w") as target:
                for member in source.namelist():
                    if name == "starter" and member == "START_HERE.md":
                        continue
                    data = source.read(member)
                    if name == "tampered" and member == "project/README.md":
                        data += b"changed"
                    target.writestr(member, data)
                if extra:
                    target.writestr(extra, b"fixture")
            rejected(name + " ZIP rejected", fragment, lambda: verify(altered))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path.cwd())
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--verify", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        elif args.verify:
            manifest = verify(args.verify)
            print(f"PASS: {manifest['label']} ZIP paths, file list and content hashes")
        else:
            if not args.plan or not args.output:
                parser.error("provide --plan and --output, or --verify, or --self-test")
            manifest = build(args.root, json.loads(args.plan.read_text(encoding="utf-8")), args.output)
            with args.output.open("rb") as stream:
                digest, size = stream_hash(stream)
            print(f"Created {args.output} ({len(manifest['files'])} files, {size} bytes)")
            print("SHA-256:", digest)
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile) as error:
        print("ERROR:", error)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
