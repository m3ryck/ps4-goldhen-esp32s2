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
