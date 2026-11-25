#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOLDHEN_SHA="c5480587d99efc2e3cc132352d9b7cf052dd3068280f1686e7fbb37d57e9ba8b"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

[ -f data/goldhen.bin ] || { echo "FAIL: data/goldhen.bin ausente"; exit 1; }
[ "$(sha256 data/goldhen.bin)" = "$GOLDHEN_SHA" ] || { echo "FAIL: sha do goldhen.bin"; exit 1; }
echo "OK: goldhen.bin sha256"

python3 - <<'PY'
import csv, json, os, sys

with open("esp.json") as f:
    manifest = json.load(f)

parts = manifest["builds"][0]["parts"]
for part in parts:
    if not os.path.exists(part["path"]):
        sys.exit(f"FAIL: {part['path']} ausente")

offsets = {os.path.basename(p["path"]): p["offset"] for p in parts}

with open("partitions.csv") as f:
    rows = [r for r in csv.reader(line for line in f if not line.startswith("#"))]
spiffs = next(r for r in rows if r[2].strip() == "spiffs")
spiffs_off = int(spiffs[3].strip(), 16)

if offsets.get("littlefs.bin") != spiffs_off:
    sys.exit(f"FAIL: offset littlefs {offsets.get('littlefs.bin')} != {spiffs_off}")

print("OK: esp.json valido e offsets batem com partitions.csv")
PY

echo "OK: verificacao completa"
