#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

GOLDHEN_SHA="c5480587d99efc2e3cc132352d9b7cf052dd3068280f1686e7fbb37d57e9ba8b"
ENV_NAME="esp32s2"
BUILD_DIR=".pio/build/$ENV_NAME"
OUT="firmware"

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

command -v pio >/dev/null 2>&1 || { echo "ERRO: pio (PlatformIO) nao encontrado"; exit 1; }
[ -f data/goldhen.bin ] || { echo "ERRO: data/goldhen.bin ausente"; exit 1; }

ACTUAL="$(sha256 data/goldhen.bin)"
if [ "$ACTUAL" != "$GOLDHEN_SHA" ]; then
  echo "ERRO: sha256 do goldhen.bin inesperado: $ACTUAL"
  exit 1
fi

pio run -e "$ENV_NAME"
pio run -e "$ENV_NAME" -t buildfs

BOOT_APP0_SRC="${HOME}/.platformio/packages/framework-arduinoespressif32/tools/partitions/boot_app0.bin"

mkdir -p "$OUT"
for f in bootloader.bin partitions.bin boot_app0.bin firmware.bin littlefs.bin; do
  if [ -f "$BUILD_DIR/$f" ]; then
    cp "$BUILD_DIR/$f" "$OUT/$f"
  elif [ "$f" = "boot_app0.bin" ] && [ -f "$BOOT_APP0_SRC" ]; then
    cp "$BOOT_APP0_SRC" "$OUT/$f"
  else
    echo "aviso: $f nao gerado"
  fi
done

python3 - "$OUT" <<'PY'
import json, os, sys

out = sys.argv[1]
parts = []
for name, off in [
    ("bootloader.bin", 4096),
    ("partitions.bin", 32768),
    ("boot_app0.bin", 57344),
    ("firmware.bin", 65536),
    ("littlefs.bin", 1638400),
]:
    if os.path.exists(os.path.join(out, name)):
        parts.append({"path": f"firmware/{name}", "offset": off})
    else:
        print(f"aviso: {name} ausente, omitido do esp.json", file=sys.stderr)

manifest = {
    "name": "PS4 14.00 GoldHEN 2.4b18.14 (ESP32-S2)",
    "version": "2.4b18.14",
    "builds": [{"chipFamily": "ESP32-S2", "parts": parts}],
}
with open("esp.json", "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print("esp.json gerado")
PY

echo "Artefatos em $OUT/:"
for f in "$OUT"/*.bin; do
  printf "%s  %s\n" "$(sha256 "$f")" "$f"
done
