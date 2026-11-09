"""Build one test APK, inspect devices, and install it on explicit targets.

Uses the existing project signing configuration. Never uninstalls, clears data,
grants permissions, changes device settings, or selects an implicit target.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from urllib.request import urlopen
import zipfile


ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / "build/device-distribution"
APK = DIST / "tsunagun-device-check.apk"
MANIFEST = DIST / "manifest.json"
SERVER = "https://tsunagun-rooms.tsunagun-room-server.workers.dev"
COMPONENT = "jp.spajam.spajam2026/.MainActivity"
WINDOWS_TOOLS = ROOT / "build/device-tools/windows"
WINDOWS_ADB = WINDOWS_TOOLS / "platform-tools/adb.exe"
WINDOWS_TOOLS_URL = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"


def run(arguments, *, capture=False):
    return subprocess.run(
        [str(value) for value in arguments], cwd=ROOT, check=True,
        text=True, capture_output=capture,
    )


def find_adb(explicit):
    candidates = [explicit]
    if sys.platform == "win32" or os.environ.get("WSL_DISTRO_NAME"):
        candidates.append(WINDOWS_ADB)
    candidates.append(shutil.which("adb"))
    for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(variable):
            candidates.append(Path(os.environ[variable]) / "platform-tools/adb")
    local = ROOT / "android/local.properties"
    if local.exists():
        for line in local.read_text(encoding="utf-8").splitlines():
            if line.startswith("sdk.dir="):
                sdk = line.split("=", 1)[1].replace("\\:", ":").replace("\\\\", "\\")
                candidates.append(Path(sdk) / "platform-tools/adb")
    candidates.extend([
        Path.home() / "Android/Sdk/platform-tools/adb",
        Path.home() / "Library/Android/sdk/platform-tools/adb",
    ])
    if os.environ.get("LOCALAPPDATA"):
        candidates.append(Path(os.environ["LOCALAPPDATA"]) / "Android/Sdk/platform-tools/adb.exe")
    for candidate in filter(None, candidates):
        resolved = shutil.which(str(candidate)) or str(candidate)
        for value in [Path(resolved), Path(f"{resolved}.exe")]:
            if value.is_file():
                return str(value)
        if explicit:
            raise ValueError("指定されたADBが見つかりません。--adb のパスを確認してください。")
    raise ValueError("ADBが見つかりません。Android SDKのplatform-toolsを用意してください。")


def adb_prefix(adb):
    # Keep the bundled Windows server separate from this WSL's Linux server.
    if os.environ.get("WSL_DISTRO_NAME") and Path(adb).resolve() == WINDOWS_ADB.resolve():
        return [adb, "-P", "5038"]
    return [adb]


def setup_windows_adb():
    if sys.platform != "win32" and not os.environ.get("WSL_DISTRO_NAME"):
        raise ValueError("Windows用ADBの準備はWindowsまたはWSLで実行してください。")
    if not WINDOWS_ADB.is_file():
        print("Google公式のWindows Platform-Toolsをbuild/へ取得します。", flush=True)
        with urlopen(WINDOWS_TOOLS_URL, timeout=60) as response:
            data = response.read()
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            for item in archive.infolist():
                relative = Path(item.filename)
                if relative.is_absolute() or ".." in relative.parts or relative.parts[0] != "platform-tools":
                    raise ValueError("Platform-Toolsアーカイブのパスが不正です。")
            WINDOWS_TOOLS.mkdir(parents=True, exist_ok=True)
            archive.extractall(WINDOWS_TOOLS)
        WINDOWS_ADB.chmod(0o755)
        (WINDOWS_TOOLS / "download.json").write_text(json.dumps({
            "url": WINDOWS_TOOLS_URL, "sha256": hashlib.sha256(data).hexdigest(),
        }, indent=2) + "\n", encoding="utf-8")
    print(run(adb_prefix(str(WINDOWS_ADB)) + ["version"], capture=True).stdout)


def devices(adb):
    output = run(adb_prefix(adb) + ["devices", "-l"], capture=True).stdout
    result = {}
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[1] in {"device", "unauthorized", "offline", "no"}:
            result[fields[0]] = {"state": fields[1], "details": " ".join(fields[2:])}
    return result


def targets(args, connected):
    selected = list(connected) if args.all else list(dict.fromkeys(args.serial))
    if not selected:
        raise ValueError("接続された端末がありません。USB接続と端末側のデバッグ許可を確認してください。")
    for serial in selected:
        state = connected.get(serial, {}).get("state", "未接続")
        if state != "device":
            raise ValueError(f"{serial}: {state}。すべての対象を確認してから再実行してください。")
    return selected


def build():
    fvm = shutil.which("fvm")
    if not fvm:
        raise ValueError("FVMが見つかりません。docs/development.md の環境準備を確認してください。")
    run([fvm, "dart", "tool/check_environment.dart", "--android"])
    run([fvm, "flutter", "pub", "get", "--enforce-lockfile"])
    run(["git", "diff", "--exit-code", "--", "pubspec.lock"])
    run([
        fvm, "flutter", "build", "apk", "--release", "--no-pub",
        f"--dart-define=TSUNAGUN_SERVER_URL={SERVER}",
    ])
    source = ROOT / "build/app/outputs/flutter-apk/app-release.apk"
    with zipfile.ZipFile(source) as archive:
        abis = sorted({p.split("/")[1] for p in archive.namelist() if p.endswith("/libapp.so")})
        if abis != ["arm64-v8a", "armeabi-v7a", "x86_64"]:
            raise ValueError(f"汎用APKに必要なABIが揃っていません: {abis}")
        for abi in abis:
            if SERVER.encode() not in archive.read(f"lib/{abi}/libapp.so"):
                raise ValueError(f"{abi}: APK内で公開接続先を確認できません。")
    DIST.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, APK)
    manifest = {
        "builtAtUtc": datetime.now(timezone.utc).isoformat(),
        "sourceCommit": run(["git", "rev-parse", "HEAD"], capture=True).stdout.strip(),
        "sourceDiff": run(["git", "diff", "--name-only", "HEAD"], capture=True).stdout.splitlines(),
        "file": APK.name, "bytes": APK.stat().st_size,
        "sha256": hashlib.sha256(APK.read_bytes()).hexdigest(),
        "server": SERVER, "mode": "release", "abis": abis,
        "signing": "existing project debug signing; device testing only",
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"実機確認用APK: {APK}")
    print(f"SHA-256: {manifest['sha256']}")


def verified_apk():
    if not APK.is_file() or not MANIFEST.is_file():
        raise ValueError("確認用APKがありません。先に build を実行してください。")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if hashlib.sha256(APK.read_bytes()).hexdigest() != manifest["sha256"]:
        raise ValueError("APKのハッシュが記録と一致しません。build で作り直してください。")
    if manifest["server"] != SERVER:
        raise ValueError("APKの接続先が公開通信先と一致しません。")
    return APK


def main():
    parser = argparse.ArgumentParser(description="つなぐんの実機確認用APKと端末導入")
    parser.add_argument("--adb", help="ADB実行ファイルのパス。通常はSDKから自動検出")
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("build", help="固定SDKで公開通信先付きの汎用release APKを作成")
    commands.add_parser("setup-windows-adb", help="Windows/WSL向けの公式ADBをbuild/に準備")
    commands.add_parser("list", help="端末一覧を表示。インストールしない")
    for name in ["info", "install"]:
        command = commands.add_parser(name)
        selection = command.add_mutually_exclusive_group(required=True)
        selection.add_argument("--serial", action="append", help="対象端末ID。複数指定可")
        selection.add_argument("--all", action="store_true", help="一覧にある全端末を明示的に選ぶ")
        if name == "install":
            command.add_argument("--no-start", action="store_true", help="導入後にアプリを起動しない")
    args = parser.parse_args()
    if args.command == "build":
        build()
        return
    if args.command == "setup-windows-adb":
        setup_windows_adb()
        return
    adb = find_adb(args.adb)
    connected = devices(adb)
    if args.command == "list":
        print(f"ADB: {adb}")
        for serial, device in connected.items():
            print(f"{serial}\t{device['state']}\t{device['details']}")
        if not connected:
            print("接続端末なし。端末を接続してUSBデバッグを許可してください。")
        return
    selected = targets(args, connected)
    apk = verified_apk() if args.command == "install" else None
    if apk and adb.lower().endswith(".exe") and sys.platform != "win32":
        apk = run(["wslpath", "-w", apk], capture=True).stdout.strip()
    for serial in selected:
        prefix = adb_prefix(adb) + ["-s", serial]
        if args.command == "info":
            print(f"--- {serial} ---")
            for prop in ["ro.product.model", "ro.build.version.release", "ro.build.version.sdk"]:
                print(f"{prop}: {run(prefix + ['shell', 'getprop', prop], capture=True).stdout.strip()}")
            for command in [["wm", "size"], ["wm", "density"], ["settings", "get", "system", "font_scale"]]:
                print(run(prefix + ["shell"] + command, capture=True).stdout.strip())
        else:
            print(f"{serial}: 同一APKを既存データを保持してインストールします。", flush=True)
            run(prefix + ["install", "-r", apk])
            if not args.no_start:
                run(prefix + ["shell", "am", "start", "-W", "-n", COMPONENT])


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"停止: {error}", file=sys.stderr)
        sys.exit(1)
