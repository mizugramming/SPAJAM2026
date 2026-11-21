"""Rebuild the bundled Japanese UI font using the Flutter SDK's font-subset."""
import argparse
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("font_subset", type=Path, help="Flutter SDK font-subset executable")
parser.add_argument("source_font", type=Path, help="NotoSansJP[wght].ttf")
args = parser.parse_args()

# Include ASCII, kana, full-width punctuation and every non-ASCII UI character.
chars = set(range(32, 127)) | set(range(0x3000, 0x3100)) | set(range(0xFF01, 0xFFA0))
for path in (root / "lib").rglob("*.dart"):
    chars.update(ord(c) for c in path.read_text(encoding="utf-8") if ord(c) > 127)
subprocess.run(
    [args.font_subset, root / "assets/fonts/workshop-sans.ttf", args.source_font],
    input=" ".join(f"optional:{code}" for code in sorted(chars)) + "\n",
    text=True,
    check=True,
)
