# Design — Host PS4 14.00 + GoldHEN 2.4b18.14 para ESP32-S2

Data: 2026-11-25
Status: aprovado pelo usuário

## 1. Contexto

O usuário tem um PS4 no firmware **14.00** e uma placa **ESP32-S2 de 4 MB**.
Antes, gravou na placa o `esp32s2FULLinstaller` do ps4macedo, que é um host
**9.00** (exfathax/USB) com GoldHEN **2.4b16.2**. Esse firmware não serve para
o 14.00.

No 14.00 o jailbreak é 100% via navegador: WebKit (Slopkit/Wobkot) + kernel
**Afterglow**, carregando o GoldHEN. O host mais atual é o `g2all` do
GamerHack, que serve **GoldHEN 2.4b18.14**, mas é um host web, não um
instalador para ESP32.

O upstream `well0nez/afterglow-web` é o host estático oficial do 14.00/14.02 e
já embute o **mesmo** `goldhen.bin` v2.4b18.14 do g2all (sha256
`c5480587d99efc2e3cc132352d9b7cf052dd3068280f1686e7fbb37d57e9ba8b`).

## 2. Objetivo

Criar um repositório público no GitHub com:

1. Um firmware para ESP32-S2 que serve, **offline**, o host Afterglow
   (12.00–14.02) com GoldHEN **2.4b18.14** embutido na flash.
2. Um **instalador web one-click** (ESP Web Tools) hospedado no GitHub Pages,
   no mesmo formato do instalador do ps4macedo.

## 3. Escopo

Dentro do escopo:

- Firmware ESP32-S2 4 MB com Wi-Fi AP, DNS de captura, HTTP estático e
  LittleFS com os arquivos do Afterglow.
- Instalador web (HTML + `esp.json`) publicado no GitHub Pages.
- Script de build reprodutível e documentação de uso.

Fora do escopo:

- Suporte a 9.00/exfathax/USB MSC (não é necessário no 14.00).
- Atualização OTA dentro do firmware (a atualização é por rebuild + reflash).
- Suporte a PS5.
- Qualquer mecanismo de contorno de PSN/ban.

## 4. Decisões

| Item | Decisão |
|---|---|
| Abordagem | Arquivos embutidos na flash + instalador one-click |
| Placa alvo | ESP32-S2, 4 MB (`esp32-s2-saola-1` no PlatformIO) |
| Framework | Arduino, via PlatformIO |
| Biblioteca HTTP | `WebServer` nativa (sem ESPAsyncWebServer/AsyncTCP) |
| Sistema de arquivos | LittleFS |
| Host embutido | `well0nez/afterglow-web` |
| GoldHEN | v2.4b18.14 (`goldhen.bin` do afterglow-web) |
| Faixa de firmware | 12.00–14.02 (alvo do usuário: 14.00) |
| Wi-Fi | SSID `PS4-GOLDHEN`, senha `12345678` |
| IP / mDNS | `10.1.1.1/24` / `ps4.local` |
| Licença do repo | AGPL-3.0 (por embutir afterglow AGPL) |
| Repo | `m3ryck/ps4-goldhen-esp32s2` (público) |

## 5. Arquitetura do firmware

Componentes, todos nativos do core Arduino/ESP-IDF (nenhuma dependência
externa):

- **Wi-Fi AP**: `WiFi.softAP(SSID, PASS)` com IP fixo `10.1.1.1/24` via
  `WiFi.softAPConfig(10.1.1.1, 10.1.1.1, 255.255.255.0)`.
- **DNS**: `DNSServer` na porta 53, respondendo qualquer consulta com
  `10.1.1.1`, para que o Guia do Usuário (`manuals.playstation.net`) abra o
  host.
- **HTTP**: `WebServer` na porta 80, servindo arquivos do LittleFS.
- **LittleFS**: montado no boot; se falhar, o firmware reinicia com log serial.
- **mDNS**: `ESPmDNS` publicando `ps4.local`.

### Regras do servidor HTTP

- `/` e `/index.html` → `index.html`.
- Arquivo existente → stream do LittleFS com o Content-Type pela extensão:
  - `.html` → `text/html`
  - `.css` → `text/css`
  - `.js` → `text/javascript`
  - `.appcache` → `text/cache-manifest`
  - `.png` → `image/png`
  - `.bin` → `application/octet-stream`
  - demais → `application/octet-stream`
- `Cache-Control`:
  - `.png` → `public, max-age=604800`
  - todo o resto → `no-cache, must-revalidate`
- Rota inexistente → `302` para `http://10.1.1.1/` (garante que qualquer URL do
  Guia do Usuário caia no host, preservando a base relativa na raiz).
- Sem endpoint de comando/auto-run: são apenas arquivos estáticos.

O MIME de `.js` e `.appcache` é obrigatório: sem `text/javascript` os módulos
ES não carregam, e sem `text/cache-manifest` o AppCache nunca preenche (o
Afterglow depende disso para rodar offline).

### Partição (4 MB, sem OTA)

`partitions.csv`:

```
# Name,   Type, SubType, Offset,   Size
nvs,      data, nvs,     0x9000,   0x4000
phy_init, data, phy,     0xd000,   0x1000
factory,  app,  factory, 0x10000,  0x180000
spiffs,   data, spiffs,  0x190000, 0x270000
```

- App: 1,5 MB (0x10000–0x190000).
- LittleFS: ~2,44 MB (0x190000–0x400000).
- Conteúdo embutido usa ~1,1 MB (incluindo `hen.bin` e `goldhen.bin`), com
  folga.
- A partição de dados chama-se `spiffs` para casar com o label padrão do
  `LittleFS.begin()`.

### Configuração

`src/config.h` concentra SSID, senha, IP, hostname e versão exibida. O
`platformio.ini` fixa `board = esp32-s2-saola-1`, `board_build.filesystem =
littlefs`, `board_build.partitions = partitions.csv` e a versão resolvida do
platform `espressif32`.

## 6. Conteúdo embutido (`data/`)

Cópia versionada de `well0nez/afterglow-web`:

- Páginas/assets: `index.html`, `jb.html`, `launch.js`, `style.css`,
  `meme.png`.
- Exploit: `jb.js`, `core.js`, `mem.js`, `int64.js`, `ps4_offsets.js`,
  `afterglow.js`.
- Cache: `cache.appcache`.
- Patches: `patchset-1200.bin` … `patchset-1402.bin`.
- Payloads: `hen.bin`, `goldhen.bin` (v2.4b18.14).
- Licenças: `LICENSE` (AGPL-3.0), `LICENSE-raw13g`.

`scripts/update-afterglow.sh` atualiza `data/` a partir do upstream e
revalida o sha256 do `goldhen.bin` (`c5480587…`).

## 7. Instalador web e publicação

- `index.html` (na raiz): página estática com `<esp-web-install-button>`
  (`esp-web-tools` via unpkg), no estilo escuro do ps4macedo, com botão
  "INICIAR", SSID/senha e créditos. Texto em PT-BR.
- `esp.json` (na raiz), gerado pelo build:

```json
{
  "name": "PS4 14.00 GoldHEN 2.4b18.14 (ESP32-S2)",
  "version": "2.4b18.14",
  "builds": [{
    "chipFamily": "ESP32-S2",
    "parts": [
      { "path": "firmware/bootloader.bin", "offset": 4096 },
      { "path": "firmware/partitions.bin", "offset": 32768 },
      { "path": "firmware/boot_app0.bin", "offset": 57344 },
      { "path": "firmware/firmware.bin", "offset": 65536 },
      { "path": "firmware/littlefs.bin", "offset": 1638400 }
    ]
  }]
}
```

- Publicação no **GitHub Pages** (HTTPS), necessário para o Web Serial,
  servindo a raiz do repo. Instalador em
  `https://m3ryck.github.io/ps4-goldhen-esp32s2/`.
- `.nojekyll` na raiz para o Pages não processar os arquivos.
- Os `.bin` ficam em `firmware/` e são servidos pelo Pages na mesma origem do
  `esp.json`.

### Fluxo de gravação (usuário)

1. Segurar BOOT e plugar a ESP32 no USB do Mac.
2. Abrir o instalador no Chrome/Edge (HTTPS).
3. Clicar "INICIAR", escolher a porta, aguardar a gravação.
4. Desconectar e plugar a ESP32 no PS4 (ou numa fonte USB).
5. No PS4: conectar ao Wi-Fi `PS4-GOLDHEN` (senha `12345678`).
6. Abrir o navegador em `http://10.1.1.1` (ou o Guia do Usuário), escolher
   GoldHEN e iniciar.

## 8. Estrutura do repositório

```
ps4-goldhen-esp32s2/
├─ index.html                 # instalador (raiz = GitHub Pages)
├─ esp.json                   # manifesto gerado pelo build
├─ .nojekyll
├─ src/main.cpp
├─ src/config.h
├─ platformio.ini
├─ partitions.csv
├─ data/                      # afterglow-web + goldhen 2.4b18.14
├─ scripts/build.sh
├─ scripts/update-afterglow.sh
├─ scripts/check-mime.sh
├─ firmware/                  # bins gerados (bootloader, app, littlefs, ...)
├─ docs/superpowers/specs/2026-11-25-ps4-goldhen-esp32s2-design.md
├─ README.md
├─ LICENSE                    # AGPL-3.0
├─ LICENSE-raw13g
└─ NOTICE
```

## 9. Pipeline de build

`scripts/build.sh`:

1. Confere dependências (`pio`, `esptool`) e a presença de `data/goldhen.bin`
   com o sha256 esperado.
2. `pio run` → compila o firmware.
3. `pio run -t buildfs` → gera a imagem LittleFS.
4. Copia de `.pio/build/<env>/` para `firmware/`: `bootloader.bin`,
   `partitions.bin`, `boot_app0.bin`, `firmware.bin`, `littlefs.bin`.
5. Gera `esp.json` na raiz com os offsets fixos e a versão do GoldHEN.
6. Imprime um resumo com tamanhos e sha256 dos artefatos.

Atualizar o GoldHEN no futuro: substituir `data/goldhen.bin`, rodar
`scripts/build.sh` e republicar.

## 10. Verificação e testes

Automatizável neste ambiente:

- Build conclui e os cinco artefatos existem em `firmware/`.
- A imagem LittleFS contém todos os arquivos esperados e o `goldhen.bin` tem
  sha256 `c5480587…`.
- `scripts/check-mime.sh` sobe um servidor local espelhando as regras de MIME
  e confere `Content-Type` de `.js`, `.appcache` e `.bin`.
- O `esp.json` é JSON válido e os offsets batem com `partitions.csv`.

Requer hardware:

- Gravar via instalador web e confirmar que o AP `PS4-GOLDHEN` aparece e que
  `curl http://10.1.1.1/` devolve o `index.html`.
- Teste final do exploit/GoldHEN no PS4 14.00 é feito pelo usuário.

## 11. Riscos e mitigações

| Risco | Mitigação |
|---|---|
| AppCache não preenche | MIME `text/cache-manifest` + `no-cache` no `.appcache` |
| Módulos ES não carregam | MIME `text/javascript` no `.js` |
| Guia do Usuário usa HTTPS | Documentar abrir `http://10.1.1.1` direto |
| Exploit de kernel instável | Aviso no README: rodar sem nada aberto; pode exigir cold boot |
| Ban de PSN | Recomendar manter o PS4 offline |
| Placa não enumerou no USB agora | Gravar/testar quando o usuário conectar |
| Download grande do PlatformIO | Primeiro build pode demorar; documentar |

## 12. Licenças e créditos

- Repositório licenciado **AGPL-3.0** por embutir `afterglow.js` e os
  patchsets (AGPL-3.0).
- Preservar `LICENSE` e `LICENSE-raw13g`; `NOTICE` com créditos a:
  well0nez/m0zz (Afterglow), raw13g, jordyidk (slopkit), SiSTRo/GoldHEN e
  ps4macedo (formato do instalador).
- `goldhen.bin` é distribuído conforme a permissão do upstream.

## 13. Critérios de sucesso

1. Repositório público com Pages ativo e instalador funcional em HTTPS.
2. Gravação one-click via Chrome/Edge conclui sem erro.
3. ESP32 cria o AP e serve o Afterglow em `http://10.1.1.1`.
4. No PS4 14.00, o GoldHEN 2.4b18.14 carrega (confirmado pelo usuário).
5. Funciona offline após o AppCache preencher.
