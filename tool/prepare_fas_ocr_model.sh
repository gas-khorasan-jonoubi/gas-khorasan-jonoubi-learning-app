#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/assets/tessdata"
mkdir -p "$DEST"

BASE="https://raw.githubusercontent.com/tesseract-ocr/tessdata_best/main"
for language in fas eng; do
  target="$DEST/${language}.traineddata"
  if [[ ! -s "$target" ]]; then
    curl --fail --location --retry 3 --retry-delay 2 \
      "$BASE/${language}.traineddata" \
      --output "$target"
  fi
  test -s "$target"
done

python3 - "$DEST" <<'PY'
import sys
from pathlib import Path
root = Path(sys.argv[1])
for name in ("fas.traineddata", "eng.traineddata"):
    path = root / name
    if not path.is_file() or path.stat().st_size < 100_000:
        raise SystemExit(f"Missing or invalid OCR model: {path}")
    print(f"{name}: {path.stat().st_size:,} bytes")
PY
