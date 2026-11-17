"""Check this repo's vendored skill bundle with Python's standard library.

This supports the single-line YAML scalar style used by this bundle, not all
YAML. Run skill-creator's quick_validate.py for full YAML validation when editing.
No network, SDK, local Codex installation or application dependencies required.
"""

import argparse
import hashlib
import json
from pathlib import Path
import re
import tempfile
from urllib.parse import unquote, urlsplit


NAME = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*\Z")
PIN = re.compile(r"[0-9a-f]{40}\Z")
HASH = re.compile(r"[0-9a-f]{64}\Z")
REPO = re.compile(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+\Z")


def scalar(value: str) -> str:
    """Accept the string-scalar subset used by the checked-in skill metadata."""
    if value.startswith('"'):
        result = json.loads(value)
        if not isinstance(result, str):
            raise ValueError("expected a string")
        return result
    if value.startswith("'") and value.endswith("'"):
        return value[1:-1].replace("''", "'")
    if (not value or value[0] in "|>[]{&*!@`%#?" or ": " in value
            or value in {"true", "false", "null", "~"}):
        raise ValueError("use a single-line string; quote YAML special values")
    return value


def metadata(path: Path) -> dict[str, str]:
    content = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(.*?)\n---\n", content, re.S)
    if not match:
        raise ValueError("missing YAML frontmatter")
    fields = {}
    for line in match[1].splitlines():
        if not line.strip() or line.startswith("#") or line[0].isspace():
            continue
        key, separator, value = line.partition(":")
        if not separator or key in fields:
            raise ValueError("invalid or duplicate frontmatter key")
        if key not in {"name", "description", "metadata", "license", "allowed-tools"}:
            raise ValueError(f"unexpected frontmatter key: {key}")
        fields[key] = scalar(value.strip()) if key in {"name", "description"} else value
    name, description = fields.get("name", ""), fields.get("description", "")
    if not NAME.fullmatch(name) or len(name) > 64 or path.parent.name != name:
        raise ValueError("skill name must match its folder and use lowercase-hyphens")
    if not description.strip() or len(description) > 1024 or re.search(r"[<>]", description):
        raise ValueError("description must be a nonempty string of at most 1024 characters")
    if re.search(r"\b(?:TODO|TBD)\b|\[TODO", content):
        raise ValueError("unfinished scaffold")
    return fields


def contained(root: Path, relative: str) -> Path:
    if not isinstance(relative, str) or Path(relative).is_absolute():
        raise ValueError("expected a relative path")
    result = (root / relative).resolve()
    if not result.is_relative_to(root.resolve()):
        raise ValueError(f"path escapes the repository: {relative}")
    return result


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors = []
    directory = root / ".agents/skills"
    skills = sorted(directory.glob("*/SKILL.md"))
    if not skills:
        errors.append("no skills found in .agents/skills")
    names = set()
    for path in skills:
        try:
            fields = metadata(path)
            if fields["name"] in names:
                raise ValueError("duplicate skill name")
            names.add(fields["name"])
            ui = path.parent / "agents/openai.yaml"
            if ui.exists():
                content = ui.read_text(encoding="utf-8")
                for field in ("display_name", "short_description"):
                    match = re.search(rf"^  {field}: (.+)$", content, re.M)
                    if not match or not scalar(match[1]):
                        raise ValueError(f"missing UI field: {field}")
                    if field == "short_description" and not 25 <= len(scalar(match[1])) <= 64:
                        raise ValueError("UI short_description must contain 25–64 characters")
                prompt = re.search(r"^  default_prompt: (.+)$", content, re.M)
                if prompt and "$" + fields["name"] not in scalar(prompt[1]):
                    raise ValueError("default_prompt must name this skill")
        except (OSError, ValueError) as error:
            errors.append(f"{path.relative_to(root)}: {error}")

    documents = sorted((root / ".agents").rglob("*.md"))
    documents += sorted((root / "docs/development-kit").rglob("*.md"))
    for path in documents:
        try:
            content = path.read_text(encoding="utf-8")
            if re.search(r"^(<<<<<<< |=======|>>>>>>> )", content, re.M):
                errors.append(f"conflict marker: {path.relative_to(root)}")
            prose = re.sub(r"^```[^\n]*\n.*?^```[^\n]*$", "", content, flags=re.M | re.S)
            for target in re.findall(r"\]\(([^)]+)\)", prose):
                url = urlsplit(target.strip("<>"))
                if url.scheme or url.netloc or not url.path:
                    continue
                destination = (path.parent / unquote(url.path)).resolve()
                if not destination.is_relative_to(root) or not destination.exists():
                    errors.append(f"broken local link: {path.relative_to(root)} -> {target}")
        except (OSError, ValueError) as error:
            errors.append(f"{path.relative_to(root)}: {error}")

    try:
        lock = json.loads((root / ".agents/skills-lock.json").read_text(encoding="utf-8"))
        if lock["schema_version"] != 1 or not lock["sources"]:
            raise ValueError("invalid lock schema")
        locked = set()
        for source in lock["sources"]:
            if not REPO.fullmatch(source["repository"]) or not PIN.fullmatch(source["commit"]):
                raise ValueError("source must have a repository and full commit SHA")
            for relative, expected in source["files"].items():
                path = contained(root, relative)
                if not HASH.fullmatch(expected) or hashlib.sha256(path.read_bytes()).hexdigest() != expected:
                    raise ValueError(f"vendor hash mismatch: {relative}")
                if path.name == "SKILL.md":
                    if path.parent.parent != directory or path.parent.name in locked:
                        raise ValueError("duplicate or invalid locked skill path")
                    locked.add(path.parent.name)
            license_path = contained(root, source["license_path"])
            if source["license_path"] not in source["files"] or not license_path.is_file():
                raise ValueError("license must exist and be covered by the lock")
            if not source["license"] or not source["skills"]:
                raise ValueError("source must list its license and skills")
            for entry in source["skills"]:
                if entry["name"] not in names or entry["name"] not in locked:
                    raise ValueError("source skill missing or not hashed")
                if entry["upstream_path"] != "skills/" + entry["name"]:
                    raise ValueError("invalid upstream skill path")
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        errors.append(f".agents/skills-lock.json: {error}")
    return errors


def self_test() -> int:
    """Exercise real failures in a temporary bundle, never mutate the repo."""
    with tempfile.TemporaryDirectory(prefix="spajam-skills-check-") as temporary:
        root = Path(temporary)
        path = root / ".agents/skills/example/SKILL.md"
        path.parent.mkdir(parents=True)
        original = ('---\nname: example\ndescription: A focused example workflow.\n---\n'
                    '# Example\n\nRead [guide](references/guide.md).\n')
        path.write_text(original, encoding="utf-8")
        guide = path.parent / "references/guide.md"
        guide.parent.mkdir()
        guide.write_text("# Guide\n", encoding="utf-8")
        license_path = root / ".agents/third-party/example.LICENSE"
        license_path.parent.mkdir()
        license_path.write_text("Fixture license\n", encoding="utf-8")
        lock = {"schema_version": 1, "sources": [{
            "repository": "example/skills", "commit": "a" * 40,
            "license": "test-fixture", "license_path": str(license_path.relative_to(root)),
            "skills": [{"name": "example", "upstream_path": "skills/example"}],
            "files": {str(file.relative_to(root)): hashlib.sha256(file.read_bytes()).hexdigest()
                      for file in (path, license_path)},
        }]}
        lock_path = root / ".agents/skills-lock.json"
        baseline = json.dumps(lock)
        lock_path.write_text(baseline, encoding="utf-8")

        def expect(label: str, fragment: str | None):
            errors = check(root)
            if (fragment is None and errors) or (fragment and not any(fragment in item for item in errors)):
                raise AssertionError(f"{label}: unexpected results: {errors}")
            print(f"PASS: {label}")

        expect("valid bundle", None)
        guide.unlink()
        expect("missing reference is rejected", "broken local link")
        guide.write_text("# Guide\n", encoding="utf-8")
        path.write_text(original + "Changed\n", encoding="utf-8")
        expect("vendor modification is rejected", "vendor hash mismatch")
        path.write_text(original.replace("name: example", "name: other"), encoding="utf-8")
        expect("folder/name mismatch is rejected", "skill name must match")
        path.write_text(original.replace("description: A focused example workflow.", "description: |"), encoding="utf-8")
        expect("unsupported metadata style is rejected", "single-line string")
        path.write_text(original, encoding="utf-8")
        lock["sources"][0]["commit"] = "main"
        lock_path.write_text(json.dumps(lock), encoding="utf-8")
        expect("moving ref is rejected", "full commit SHA")
        lock_path.write_text(baseline.replace(".agents/third-party/example.LICENSE", "../outside.LICENSE"), encoding="utf-8")
        expect("path traversal is rejected", "path escapes")
        lock_path.write_text(baseline, encoding="utf-8")
        expect("restored bundle", None)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return self_test()
    errors = check(args.root)
    if errors:
        print("\n".join(errors))
        return 1
    print("PASS: skill metadata, references, pinned vendor sources and hashes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
