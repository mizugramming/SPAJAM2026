"""Validate this documentation kit using only the Python standard library."""

from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit


REQUIRED = (
    "AGENTS.md",
    "CLAUDE.md",
    "README.md",
    ".github/copilot-instructions.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/workflows/check.yml",
    "docs/ai_prompts.md",
    "docs/reuse_rules.md",
    "docs/repository_maintenance.md",
    "templates/project/README.md",
    "templates/project/.github/PULL_REQUEST_TEMPLATE.md",
    "templates/project/docs/app_design.md",
    "templates/project/docs/project_structure.md",
    "templates/project/docs/development.md",
    "templates/project/docs/assets.md",
)
APP_PATHS = (
    "lib", "assets", "test", "android", "ios", "web", "linux", "macos",
    "windows", "practice", "pubspec.yaml", "pubspec.lock", ".metadata",
    "analysis_options.yaml", "yohaku_app_design.md",
    ".github/workflows/flutter.yml", "docs/screenshots",
)
SHARED = (
    "AGENTS.md", "CLAUDE.md", ".github/copilot-instructions.md",
    "docs/ai_prompts.md",
)


def check(root: Path) -> list[str]:
    root = root.resolve()
    errors = []
    for name in REQUIRED:
        if not (root / name).is_file():
            errors.append(f"Missing required file: {name}")
    for name in APP_PATHS:
        if (root / name).exists():
            errors.append(f"App files do not belong in the kit: {name}")

    for path in sorted(root.rglob("*.md")):
        relative = path.relative_to(root)
        if ".git" in relative.parts:
            continue
        content = path.read_text(encoding="utf-8")
        if re.search(r"^(<<<<<<< |=======|>>>>>>> )", content, re.MULTILINE):
            errors.append(f"Conflict marker: {relative}")
        # Ignore examples in fenced blocks; only inspect inline Markdown links.
        prose = re.sub(r"^```[^\n]*\n.*?^```[^\n]*$", "", content,
                       flags=re.MULTILINE | re.DOTALL)
        for target in re.findall(r"\]\(([^)]+)\)", prose):
            url = urlsplit(target.strip("<>"))
            if url.scheme or url.netloc or not url.path:
                continue
            destination = (path.parent / unquote(url.path)).resolve()
            if not destination.is_relative_to(root) or not destination.exists():
                errors.append(f"Broken local link in {relative}: {target}")

    for name in SHARED:
        path = root / name
        if path.is_file() and re.search(
            r"余白|SPAJAM2026|rehearsal/02|yohaku|3\.41\.5|SpaceRecord",
            path.read_text(encoding="utf-8"),
        ):
            errors.append(f"App-specific content in reusable guidance: {name}")
    prompts = root / "docs/ai_prompts.md"
    if prompts.is_file():
        text = prompts.read_text(encoding="utf-8")
        if text.count("```text") != 2 or "【" in text:
            errors.append("Expected two copy-ready prompts without fill-in fields")
    return errors


if __name__ == "__main__":
    problems = check(Path(__file__).resolve().parent.parent)
    if problems:
        print("\n".join(problems), file=sys.stderr)
        sys.exit(1)
    print("PASS: required files, local links, reusable prompts, and kit scope")
