"""Validate honban application documents, layout and pinned SDK configuration.

The filename is retained for links copied from the reusable kit. On honban this
checks an application repository: application files are required, not forbidden.
Flutter analysis/tests/builds run separately in the CI `check` job.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
from urllib.parse import unquote, urlsplit


REQUIRED = (
    "AGENTS.md", "CLAUDE.md", "README.md",
    ".github/copilot-instructions.md", ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/workflows/check.yml", ".fvmrc", "tool/toolchain.json",
    "tool/check_environment.dart", "pubspec.yaml", "pubspec.lock",
    "analysis_options.yaml", "lib/main.dart", "lib/domain/models.dart",
    "lib/domain/reward_rules.dart", "lib/data/demo_controller.dart",
    "lib/app/tsunagun_app.dart", "lib/features/demo/demo_page.dart",
    "docs/ai_prompts.md", "docs/app_design.md", "docs/decisions.md",
    "docs/development.md", "docs/feature_integration.md", "docs/assets.md",
    "docs/tsunagun/APP_DESIGN.md", "docs/repository_maintenance.md",
    "android/app/build.gradle.kts", "web/index.html",
)
SKIP_DIRS = {
    ".git", ".fvm", ".dart_tool", "build", ".gradle", ".idea",
    ".venv", "node_modules", "__pycache__",
}


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors = []
    for name in REQUIRED:
        if not (root / name).is_file():
            errors.append(f"Missing required file: {name}")
    if not list((root / "test").rglob("*_test.dart")):
        errors.append("At least one Flutter test is required")

    for directory, children, files in os.walk(root):
        children[:] = [child for child in children if child not in SKIP_DIRS]
        for name in sorted(files):
            if not name.endswith(".md"):
                continue
            path = Path(directory) / name
            relative = path.relative_to(root)
            content = path.read_text(encoding="utf-8")
            if re.search(r"^(<<<<<<< |=======|>>>>>>> )", content, re.MULTILINE):
                errors.append(f"Conflict marker: {relative}")
            prose = re.sub(r"^```[^\n]*\n.*?^```[^\n]*$", "", content,
                           flags=re.MULTILINE | re.DOTALL)
            for target in re.findall(r"\]\(([^)]+)\)", prose):
                url = urlsplit(target.strip("<>"))
                if url.scheme or url.netloc or not url.path:
                    continue
                destination = (path.parent / unquote(url.path)).resolve()
                if not destination.is_relative_to(root) or not destination.exists():
                    errors.append(f"Broken local link in {relative}: {target}")

    try:
        fvm = json.loads((root / ".fvmrc").read_text(encoding="utf-8"))
        chain = json.loads((root / "tool/toolchain.json").read_text(encoding="utf-8"))
        for value, label in ((fvm["flutter"], "Flutter"), (chain["dart"], "Dart")):
            if not re.fullmatch(r"\d+\.\d+\.\d+", value):
                errors.append(f"{label} must pin a complete stable version")
        if not re.fullmatch(r"\d+", chain["java"]):
            errors.append("Java must pin its major version")
        pubspec = (root / "pubspec.yaml").read_text(encoding="utf-8")
        sdk = re.search(r"^  sdk: *[\"']?>=([^ <]+)", pubspec, re.MULTILINE)
        flutter = re.search(r"^  flutter: *[\"']?>=([^ <\"']+)", pubspec, re.MULTILINE)
        if not sdk or sdk[1] != chain["dart"]:
            errors.append("pubspec Dart minimum must match tool/toolchain.json")
        if not flutter or flutter[1] != fvm["flutter"]:
            errors.append("pubspec Flutter minimum must match .fvmrc")
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors.append(f"Cannot validate SDK configuration: {error}")

    prompts = root / "docs/ai_prompts.md"
    if prompts.is_file():
        content = prompts.read_text(encoding="utf-8")
        if content.count("```text") != 2 or "【" in content:
            errors.append("Expected two copy-ready prompts without fill-in fields")

    tracked = subprocess.run(
        ["git", "ls-files", "-z"], cwd=root, capture_output=True, check=False,
    )
    if tracked.returncode:
        errors.append("Could not inspect tracked files")
    else:
        for raw in tracked.stdout.decode("utf-8").split("\0"):
            if not raw:
                continue
            path = Path(raw)
            if set(path.parts) & SKIP_DIRS:
                errors.append(f"Tracked cache or generated directory: {raw}")
            if (path.name in {"local.properties", "key.properties", ".env"}
                    or path.suffix in {".jks", ".keystore", ".p12", ".pem"}
                    or path.name.endswith("Zone.Identifier")):
                errors.append(f"Tracked local/credential file: {raw}")
    return errors


if __name__ == "__main__":
    problems = check(Path(__file__).resolve().parent.parent)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)
    print("PASS: application layout, document links, pinned SDKs and tracked files")
