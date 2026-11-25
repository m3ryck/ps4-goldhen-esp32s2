#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8765}"

cd "$ROOT/data"

python3 - "$PORT" <<'PY' &
import sys
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".css": "text/css",
        ".bin": "application/octet-stream",
        ".appcache": "text/cache-manifest",
    }
    def log_message(self, *args):
        pass

ThreadingHTTPServer(("127.0.0.1", int(sys.argv[1])), Handler).serve_forever()
PY
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT

sleep 1

check() {
  local path="$1" expected="$2"
  local got
  got="$(curl -sI "http://127.0.0.1:$PORT/$path" | tr -d '\r' | awk -F': ' 'tolower($1)=="content-type"{print $2}')"
  if [ "$got" != "$expected" ]; then
    echo "FAIL $path: '$got' != '$expected'"
    exit 1
  fi
  echo "OK $path -> $got"
}

check "jb.js" "text/javascript"
check "cache.appcache" "text/cache-manifest"
check "goldhen.bin" "application/octet-stream"
check "style.css" "text/css"
check "index.html" "text/html"

echo "MIME OK"
