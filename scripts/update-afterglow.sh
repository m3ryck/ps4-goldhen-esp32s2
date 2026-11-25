#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

git clone --depth 1 https://github.com/well0nez/afterglow-web.git "$TMP/afterglow-web"

mkdir -p data
cp \
  "$TMP/afterglow-web/index.html" \
  "$TMP/afterglow-web/jb.html" \
  "$TMP/afterglow-web/launch.js" \
  "$TMP/afterglow-web/style.css" \
  "$TMP/afterglow-web/meme.png" \
  "$TMP/afterglow-web/jb.js" \
  "$TMP/afterglow-web/core.js" \
  "$TMP/afterglow-web/mem.js" \
  "$TMP/afterglow-web/int64.js" \
  "$TMP/afterglow-web/ps4_offsets.js" \
  "$TMP/afterglow-web/afterglow.js" \
  "$TMP/afterglow-web/cache.appcache" \
  "$TMP/afterglow-web/hen.bin" \
  "$TMP/afterglow-web/goldhen.bin" \
  data/

cp "$TMP"/afterglow-web/patchset-*.bin data/

cp "$TMP/afterglow-web/LICENSE" LICENSE
cp "$TMP/afterglow-web/LICENSE-raw13g" LICENSE-raw13g
cp "$TMP/afterglow-web/LICENSE" data/LICENSE
cp "$TMP/afterglow-web/LICENSE-raw13g" data/LICENSE-raw13g

echo "afterglow-web atualizado para $(git -C "$TMP/afterglow-web" rev-parse --short HEAD)"
