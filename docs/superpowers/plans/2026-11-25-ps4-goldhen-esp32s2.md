# Host PS4 14.00 + GoldHEN 2.4b18.14 para ESP32-S2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar um repositório com firmware ESP32-S2 que serve, offline, o host Afterglow (PS4 12.00–14.02) com GoldHEN 2.4b18.14 embutido, mais um instalador web one-click no GitHub Pages.

**Architecture:** Um sketch Arduino (PlatformIO) cria Wi-Fi AP `10.1.1.1`, DNS de captura e um `WebServer` que serve arquivos do LittleFS. Os arquivos estáticos do `well0nez/afterglow-web` (incluindo `goldhen.bin` v2.4b18.14) são embutidos no LittleFS via `pio run -t buildfs`. O site publica `index.html` + `esp.json` + `firmware/*.bin` na raiz do repo, e o GitHub Pages (HTTPS) serve o instalador ESP Web Tools.

**Tech Stack:** ESP32-S2, PlatformIO (`espressif32`, Arduino core 2.x), `WiFi`, `WebServer`, `DNSServer`, `LittleFS`, `ESPmDNS`, ESP Web Tools, GitHub Pages, `gh` CLI.

---

## File Structure

- `platformio.ini` — alvo ESP32-S2, framework Arduino, LittleFS, partições.
- `partitions.csv` — app 1,5 MB + spiffs/LittleFS 2,44 MB, sem OTA.
- `src/config.h` — SSID, senha, hostname, label de versão.
- `src/mime.h` — mapeamento puro de extensão → Content-Type/Cache-Control (testável nativo).
- `src/main.cpp` — AP + DNS + HTTP + LittleFS.
- `tests/test_mime.cpp` — teste nativo do `mime.h`.
- `scripts/update-afterglow.sh` — baixa/atualiza `data/` do upstream e valida o sha do GoldHEN.
- `scripts/build.sh` — build do firmware + filesystem, copia bins, gera `esp.json`.
- `scripts/verify.sh` — valida `esp.json`, offsets e sha.
- `scripts/check-mime.sh` — servidor local espelhando MIME para checar os assets.
- `data/` — cópia versionada do afterglow-web + licenças.
- `index.html` — instalador (raiz = GitHub Pages).
- `esp.json` — manifesto gerado pelo build.
- `.nojekyll` — desliga Jekyll no Pages.
- `firmware/` — bins gerados e commitados (servidos pelo Pages).
- `README.md`, `NOTICE`, `LICENSE`, `LICENSE-raw13g`.
- `docs/superpowers/specs/2026-11-25-ps4-goldhen-esp32s2-design.md` — spec aprovado.

---

### Task 1: Scaffold do projeto + toolchain

**Files:**
- Create: `.gitignore`
- Create: `platformio.ini`
- Create: `partitions.csv`
- Create: `src/config.h`
- Create: `src/main.cpp` (stub mínimo)

- [ ] **Step 1: Criar `.gitignore`**

```gitignore
.pio/
.vscode/
.DS_Store
```

- [ ] **Step 2: Criar `platformio.ini`**

```ini
[env:esp32s2]
platform = espressif32@^6.9.0
board = esp32-s2-saola-1
framework = arduino
board_build.filesystem = littlefs
board_build.partitions = partitions.csv
monitor_speed = 115200
build_flags = -DCORE_DEBUG_LEVEL=0
```

- [ ] **Step 3: Criar `partitions.csv`**

```csv
# Name,Type,SubType,Offset,Size
nvs,data,nvs,0x9000,0x4000
phy_init,data,phy,0xd000,0x1000
factory,app,factory,0x10000,0x180000
spiffs,data,spiffs,0x190000,0x270000
```

- [ ] **Step 4: Criar `src/config.h`**

```cpp
#pragma once

#define WIFI_SSID "PS4-GOLDHEN"
#define WIFI_PASS "12345678"
#define HOSTNAME  "ps4"
#define FW_LABEL  "PS4 14.00 - GoldHEN 2.4b18.14"
```

- [ ] **Step 5: Criar `src/main.cpp` stub**

```cpp
#include <Arduino.h>

void setup() {
  Serial.begin(115200);
  Serial.println("boot");
}

void loop() {
  delay(1000);
}
```

- [ ] **Step 6: Compilar o stub**

Run: `pio run -e esp32s2`
Expected: termina com `SUCCESS` e gera `.pio/build/esp32s2/firmware.bin`.
(No primeiro build o PlatformIO baixa platform/toolchain; pode demorar.)

- [ ] **Step 7: Commit**

```bash
git add .gitignore platformio.ini partitions.csv src/config.h src/main.cpp
git commit -m "chore: scaffold PlatformIO ESP32-S2 e tabela de particoes"
```

---

### Task 2: Embutir o host Afterglow em `data/`

**Files:**
- Create: `scripts/update-afterglow.sh`
- Create (via script): `data/*`, `LICENSE`, `LICENSE-raw13g`

- [ ] **Step 1: Criar `scripts/update-afterglow.sh`**

```bash
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
```

- [ ] **Step 2: Dar permissão e rodar**

Run:
```bash
chmod +x scripts/update-afterglow.sh
./scripts/update-afterglow.sh
```
Expected: imprime `afterglow-web atualizado para <hash>` e preenche `data/`.

- [ ] **Step 3: Validar o GoldHEN e os arquivos**

Run:
```bash
shasum -a 256 data/goldhen.bin
ls data
```
Expected:
- sha256 `c5480587d99efc2e3cc132352d9b7cf052dd3068280f1686e7fbb37d57e9ba8b`
- `data/` contém `index.html jb.html launch.js style.css meme.png jb.js core.js mem.js int64.js ps4_offsets.js afterglow.js cache.appcache hen.bin goldhen.bin patchset-1200.bin … patchset-1402.bin LICENSE LICENSE-raw13g`.

- [ ] **Step 4: Commit**

```bash
git add scripts/update-afterglow.sh data LICENSE LICENSE-raw13g
git commit -m "feat: embute afterglow-web e GoldHEN 2.4b18.14 em data/"
```

---

### Task 3: Mapeamento de MIME (TDD)

**Files:**
- Create: `tests/test_mime.cpp`
- Create: `src/mime.h`

- [ ] **Step 1: Escrever o teste que falha**

`tests/test_mime.cpp`:
```cpp
#include <cassert>
#include <cstring>
#include "mime.h"

int main() {
  assert(std::strcmp(contentTypeFor("/jb.js"), "text/javascript") == 0);
  assert(std::strcmp(contentTypeFor("/cache.appcache"), "text/cache-manifest") == 0);
  assert(std::strcmp(contentTypeFor("/goldhen.bin"), "application/octet-stream") == 0);
  assert(std::strcmp(contentTypeFor("/style.css"), "text/css") == 0);
  assert(std::strcmp(contentTypeFor("/index.html"), "text/html") == 0);
  assert(std::strcmp(contentTypeFor("/meme.png"), "image/png") == 0);
  assert(std::strcmp(cacheControlFor("/meme.png"), "public, max-age=604800") == 0);
  assert(std::strcmp(cacheControlFor("/jb.js"), "no-cache, must-revalidate") == 0);
  return 0;
}
```

- [ ] **Step 2: Rodar e ver falhar**

Run: `g++ -std=c++17 -Isrc tests/test_mime.cpp -o /tmp/test_mime && /tmp/test_mime`
Expected: FAIL de compilação com `mime.h: No such file or directory`.

- [ ] **Step 3: Implementar `src/mime.h`**

```cpp
#pragma once
#include <cstring>

inline bool endsWith(const char* s, const char* suffix) {
  size_t ls = std::strlen(s);
  size_t lf = std::strlen(suffix);
  return ls >= lf && std::strcmp(s + ls - lf, suffix) == 0;
}

inline const char* contentTypeFor(const char* path) {
  if (endsWith(path, ".html"))     return "text/html";
  if (endsWith(path, ".css"))      return "text/css";
  if (endsWith(path, ".js"))       return "text/javascript";
  if (endsWith(path, ".appcache")) return "text/cache-manifest";
  if (endsWith(path, ".png"))      return "image/png";
  if (endsWith(path, ".bin"))      return "application/octet-stream";
  return "application/octet-stream";
}

inline const char* cacheControlFor(const char* path) {
  if (endsWith(path, ".png")) return "public, max-age=604800";
  return "no-cache, must-revalidate";
}
```

- [ ] **Step 4: Rodar e ver passar**

Run: `g++ -std=c++17 -Isrc tests/test_mime.cpp -o /tmp/test_mime && /tmp/test_mime && echo OK`
Expected: `OK` (exit 0).

- [ ] **Step 5: Commit**

```bash
git add tests/test_mime.cpp src/mime.h
git commit -m "feat: mapeamento de MIME e Cache-Control com teste nativo"
```

---

### Task 4: Firmware (AP + DNS + HTTP + LittleFS)

**Files:**
- Modify: `src/main.cpp` (substituir o stub)
- Uses: `src/config.h`, `src/mime.h`

- [ ] **Step 1: Substituir `src/main.cpp` pelo firmware completo**

```cpp
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <DNSServer.h>
#include <LittleFS.h>
#include <ESPmDNS.h>
#include "config.h"
#include "mime.h"

static WebServer server(80);
static DNSServer dnsServer;

static String stripQuery(const String &uri) {
  int q = uri.indexOf('?');
  return q >= 0 ? uri.substring(0, q) : uri;
}

static bool serveFile(const String &path) {
  String p = path;
  if (p.length() == 0 || p == "/") p = "/index.html";
  if (!LittleFS.exists(p)) return false;
  File f = LittleFS.open(p, "r");
  if (!f) return false;
  server.sendHeader("Cache-Control", cacheControlFor(p.c_str()));
  server.streamFile(f, contentTypeFor(p.c_str()));
  f.close();
  return true;
}

void setup() {
  Serial.begin(115200);

  if (!LittleFS.begin(false)) {
    Serial.println("LittleFS mount failed; reiniciando");
    delay(2000);
    ESP.restart();
  }

  IPAddress apIP(10, 1, 1, 1);
  IPAddress apMask(255, 255, 255, 0);
  WiFi.mode(WIFI_AP);
  WiFi.softAPConfig(apIP, apIP, apMask);
  WiFi.softAP(WIFI_SSID, WIFI_PASS);
  delay(200);
  Serial.printf("[%s] AP '%s' em http://%s/\n", FW_LABEL, WIFI_SSID, apIP.toString().c_str());

  dnsServer.start(53, "*", apIP);

  if (MDNS.begin(HOSTNAME)) {
    MDNS.addService("http", "tcp", 80);
  }

  server.on("/", []() { serveFile("/index.html"); });
  server.onNotFound([]() {
    String path = stripQuery(server.uri());
    if (!serveFile(path)) {
      server.sendHeader("Location", "http://10.1.1.1/");
      server.send(302, "text/plain", "");
    }
  });

  server.begin();
}

void loop() {
  dnsServer.processNextRequest();
  server.handleClient();
  delay(1);
}
```

- [ ] **Step 2: Compilar o firmware**

Run: `pio run -e esp32s2`
Expected: `SUCCESS`.

- [ ] **Step 3: Gerar a imagem LittleFS**

Run: `pio run -e esp32s2 -t buildfs`
Expected: `SUCCESS` e `.pio/build/esp32s2/littlefs.bin` criado.

- [ ] **Step 4: Commit**

```bash
git add src/main.cpp
git commit -m "feat: firmware AP/DNS/HTTP servindo afterglow do LittleFS"
```

---

### Task 5: Pipeline de build + `esp.json`

**Files:**
- Create: `scripts/build.sh`
- Create (via script): `firmware/*.bin`, `esp.json`

- [ ] **Step 1: Criar `scripts/build.sh`**

```bash
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

mkdir -p "$OUT"
for f in bootloader.bin partitions.bin boot_app0.bin firmware.bin littlefs.bin; do
  if [ -f "$BUILD_DIR/$f" ]; then
    cp "$BUILD_DIR/$f" "$OUT/$f"
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
```

- [ ] **Step 2: Dar permissão e rodar**

Run:
```bash
chmod +x scripts/build.sh
./scripts/build.sh
```
Expected: termina com `esp.json gerado` e lista sha256 de `bootloader.bin`, `partitions.bin`, `boot_app0.bin`, `firmware.bin`, `littlefs.bin`.

- [ ] **Step 3: Validar o manifesto**

Run: `python3 -m json.tool esp.json`
Expected: JSON válido com 5 `parts`.

- [ ] **Step 4: Commit**

```bash
git add scripts/build.sh firmware esp.json
git commit -m "feat: build reproduzivel gera bins e esp.json"
```

---

### Task 6: Verificação automatizada

**Files:**
- Create: `scripts/verify.sh`

- [ ] **Step 1: Criar `scripts/verify.sh`**

```bash
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
```

- [ ] **Step 2: Rodar**

Run:
```bash
chmod +x scripts/verify.sh
./scripts/verify.sh
```
Expected:
```
OK: goldhen.bin sha256
OK: esp.json valido e offsets batem com partitions.csv
OK: verificacao completa
```

- [ ] **Step 3: Commit**

```bash
git add scripts/verify.sh
git commit -m "test: verifica esp.json, offsets e sha do goldhen"
```

---

### Task 7: Instalador web + documentação

**Files:**
- Create: `index.html`
- Create: `.nojekyll`
- Create: `README.md`
- Create: `NOTICE`

- [ ] **Step 1: Criar `index.html`**

```html
<!doctype html>
<html lang="pt-BR">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PS4 14.00 — GoldHEN 2.4b18.14 (ESP32-S2)</title>
<script type="module" src="https://unpkg.com/esp-web-tools@8.0.6/dist/web/install-button.js?module"></script>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0; min-height: 100vh; display: flex; flex-direction: column;
    align-items: center; justify-content: center; gap: 14px; padding: 32px 18px;
    background: radial-gradient(circle at 50% 0%, #1a0d0d, #05070d 70%);
    color: #e6ebf2; font-family: system-ui, -apple-system, sans-serif; text-align: center;
  }
  h1 { margin: 0; font-size: clamp(22px, 4vw, 40px); color: #fff; text-shadow: 2px 2px #ff5757; }
  .sub { margin: 0; color: #ff9a9a; font-weight: 700; letter-spacing: .04em; }
  esp-web-install-button button {
    margin-top: 12px; padding: 14px 34px; font: 700 20px/1 system-ui, sans-serif;
    text-transform: uppercase; color: #fff; cursor: pointer;
    background: #b31b2b; border: 2px solid #ff5757; border-radius: 6px;
    box-shadow: 0 5px 0 #5c0d15;
  }
  esp-web-install-button button:hover { background: #d62436; }
  esp-web-install-button button:active { transform: translateY(4px); box-shadow: none; }
  .hint { max-width: 560px; color: #c8ced8; line-height: 1.5; }
  .wifi { padding: 10px 14px; border: 1px solid #2a3442; border-radius: 6px; background: #0e1116; }
  footer { max-width: 720px; margin-top: 18px; color: #6c7787; font-size: 12px; line-height: 1.5; }
  code, b { color: #fff; }
</style>
</head>
<body>
  <h1>PS4 14.00 — GoldHEN 2.4b18.14</h1>
  <p class="sub">Host Afterglow para ESP32-S2 (4 MB)</p>

  <esp-web-install-button manifest="esp.json">
    <button slot="activate">INICIAR</button>
    <span slot="unsupported">Use Chrome ou Edge.</span>
    <span slot="not-allowed">Abra esta página por HTTPS (GitHub Pages).</span>
  </esp-web-install-button>

  <p class="hint">Segure <b>BOOT</b>, plugue a ESP32 no USB e clique em <b>INICIAR</b>.</p>
  <p class="wifi">Wi-Fi: <b>PS4-GOLDHEN</b> · Senha: <b>12345678</b> · Abra <b>http://10.1.1.1</b></p>

  <footer>
    Créditos: well0nez/m0zz (Afterglow), raw13g, jordyidk, SiSTRo/GoldHEN e
    ps4macedo (formato do instalador). Uso por sua conta e risco; mantenha o
    PS4 offline.
  </footer>
</body>
</html>
```

- [ ] **Step 2: Criar `.nojekyll` vazio**

Run: `touch .nojekyll`
Expected: arquivo vazio na raiz.

- [ ] **Step 3: Criar `README.md`**

```markdown
# PS4 14.00 — GoldHEN 2.4b18.14 para ESP32-S2

Host **offline** para PS4 firmware **12.00–14.02** (alvo: 14.00), rodando numa
ESP32-S2 de 4 MB. Embute o [afterglow-web](https://github.com/well0nez/afterglow-web)
e o **GoldHEN v2.4b18.14**.

## Instalar

1. Abra o instalador: **https://m3ryck.github.io/ps4-goldhen-esp32s2/**
2. Segure **BOOT** e plugue a ESP32 no USB do computador.
3. No Chrome/Edge, clique em **INICIAR**, escolha a porta e aguarde.
4. Pluge a ESP32 no PS4 (ou numa fonte USB).

## Usar no PS4

1. Conecte ao Wi-Fi **PS4-GOLDHEN** (senha `12345678`).
2. Abra o navegador em **http://10.1.1.1** (ou o Guia do Usuário).
3. Escolha **GoldHEN** e inicie. Na primeira vez o AppCache preenche; depois
   funciona offline.

## Build

Requisitos: PlatformIO (`pio`), Python 3, git.

```bash
./scripts/update-afterglow.sh   # baixa/atualiza data/ (opcional se já versionado)
./scripts/build.sh              # compila e gera firmware/ + esp.json
./scripts/verify.sh             # valida offsets e sha
```

Atualizar o GoldHEN: substitua `data/goldhen.bin` (e o sha em
`scripts/build.sh`/`scripts/verify.sh`), rode `./scripts/build.sh` e publique.

## Estrutura

- `src/` firmware (AP, DNS, HTTP, LittleFS).
- `data/` arquivos do afterglow-web embutidos na flash.
- `firmware/` bins gerados e servidos pelo Pages.
- `scripts/` atualização, build e verificação.

## Problemas comuns

- **Web Serial não aparece**: use Chrome/Edge e abra por HTTPS.
- **Placa não entra em gravação**: segure BOOT ao plugar.
- **Guia do Usuário não abre**: digite `http://10.1.1.1` no navegador.
- **AppCache não preenche**: limpe os dados do site no navegador do PS4 e
  recarregue.

## Aviso

Exploit de kernel: pode travar o console. Rode sem nada aberto e mantenha o PS4
offline (risco de ban). Sem garantias.

## Licenças e créditos

AGPL-3.0. Veja `LICENSE`, `LICENSE-raw13g` e `NOTICE`.
```

- [ ] **Step 4: Criar `NOTICE`**

```text
Este projeto embute o afterglow-web (https://github.com/well0nez/afterglow-web),
licenciado sob AGPL-3.0 (LICENSE). O host deriva de:
  - raw13g (jb.js, ps4_offsets.js, scaffolding) — MIT (LICENSE-raw13g)
  - jordyidk/slopkit (core.js, mem.js, int64.js) — ver TECHNICAL.md upstream
  - SiSTRo/GoldHEN (goldhen.bin v2.4b18.14) — conforme permissao do upstream
O formato do instalador foi inspirado no esp32s2FULLinstaller de ps4macedo.

O firmware, scripts e documentacao deste repositorio sao distribuidos sob
AGPL-3.0.
```

- [ ] **Step 5: Validar o instalador**

Run:
```bash
grep -q 'esp-web-install-button manifest="esp.json"' index.html && echo OK
```
Expected: `OK`.

- [ ] **Step 6: Commit**

```bash
git add index.html .nojekyll README.md NOTICE
git commit -m "feat: instalador web, README e creditos"
```

---

### Task 8: Checagem de MIME dos assets

**Files:**
- Create: `scripts/check-mime.sh`

- [ ] **Step 1: Criar `scripts/check-mime.sh`**

```bash
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
```

- [ ] **Step 2: Rodar**

Run:
```bash
chmod +x scripts/check-mime.sh
./scripts/check-mime.sh
```
Expected:
```
OK jb.js -> text/javascript
OK cache.appcache -> text/cache-manifest
OK goldhen.bin -> application/octet-stream
OK style.css -> text/css
OK index.html -> text/html
MIME OK
```

- [ ] **Step 3: Commit**

```bash
git add scripts/check-mime.sh
git commit -m "test: confere Content-Type dos assets do host"
```

---

### Task 9: Publicar no GitHub + Pages

**Files:** nenhum (operação de repositório).

- [ ] **Step 1: Renomear a branch para `main`**

Run: `git branch -M main`
Expected: branch atual `main`.

- [ ] **Step 2: Criar o repo público e enviar**

Run:
```bash
gh repo create m3ryck/ps4-goldhen-esp32s2 --public --source=. --remote=origin --push
```
Expected: cria `https://github.com/m3ryck/ps4-goldhen-esp32s2` e faz push de `main`.
Se o repo já existir, use:
```bash
git remote add origin git@github.com:m3ryck/ps4-goldhen-esp32s2.git
git push -u origin main
```

- [ ] **Step 3: Ativar o GitHub Pages na raiz**

Run:
```bash
gh api -X POST repos/m3ryck/ps4-goldhen-esp32s2/pages --input - <<'JSON'
{"source":{"branch":"main","path":"/"}}
JSON
```
Expected: JSON com `"html_url": "https://m3ryck.github.io/ps4-goldhen-esp32s2/"`.

- [ ] **Step 4: Conferir o status do Pages**

Run:
```bash
gh api repos/m3ryck/ps4-goldhen-esp32s2/pages --jq '.html_url, .status'
```
Expected: imprime a URL e um status (`building` ou `built`). O primeiro build
pode levar alguns minutos.

- [ ] **Step 5: (sem commit — operação remota)**

---

### Task 10: Smoke test no hardware (quando a placa estiver plugada)

**Files:** nenhum.

- [ ] **Step 1: Identificar a porta**

Run: `ls /dev/cu.*`
Expected: uma porta tipo `/dev/cu.usbmodem*`, `/dev/cu.wchusbserial*` ou
`/dev/cu.SLAB_USBtoUART` (com a placa em modo gravação: segure BOOT ao plugar).

- [ ] **Step 2: Gravar pelo PlatformIO (alternativa ao instalador web)**

Run: `pio run -e esp32s2 -t upload --upload-port /dev/cu.usbmodemXXXX`
Expected: `SUCCESS`.

- [ ] **Step 3: Validar o servidor**

Conecte o Mac ao Wi-Fi `PS4-GOLDHEN` e rode:
```bash
curl -s http://10.1.1.1/ | head -n 3
curl -sI http://10.1.1.1/jb.js | tr -d '\r' | grep -i content-type
curl -sI http://10.1.1.1/cache.appcache | tr -d '\r' | grep -i content-type
```
Expected:
- HTML começando com `<!doctype html>`
- `Content-Type: text/javascript`
- `Content-Type: text/cache-manifest`

- [ ] **Step 4: Teste final no PS4 (usuário)**

No PS4 14.00: Wi-Fi `PS4-GOLDHEN` → navegador → `http://10.1.1.1` → escolher
GoldHEN → iniciar. Confirmar que o GoldHEN 2.4b18.14 carrega.

---

## Verificação final (checklist)

- [ ] `./scripts/verify.sh` imprime `OK: verificacao completa`.
- [ ] `./scripts/check-mime.sh` imprime `MIME OK`.
- [ ] `esp.json` tem 5 `parts` e offsets corretos.
- [ ] `firmware/` contém os 5 bins commitados.
- [ ] Pages ativo em `https://m3ryck.github.io/ps4-goldhen-esp32s2/`.
- [ ] Instalador grava a placa via Chrome/Edge.
- [ ] PS4 14.00 carrega o GoldHEN 2.4b18.14 (usuário confirma).
