# 0005 — FFprobe/FFmpeg em build LGPL

- Status: aceita
- Data: 2026-10-26

## Contexto
Para vídeos, é preciso ler duração, codecs, fps e a data interna (QuickTime `creation_time`, normalmente em UTC) e, como fallback, gerar a miniatura (spec §8, §4.1).

## Alternativas consideradas
- **Builds GPL** (ex.: gyan.dev "full"): incluem x264/x265, que são GPL. Desnecessário, porque só lemos.
- **Media Foundation (Windows)**: sem dependência externa, mas com metadados limitados, e o HEVC depende de uma extensão paga da Store.
- **ExifTool para vídeo**: lê as datas, mas não gera quadros para miniatura.

## Decisão
- `ffprobe.exe` e `ffmpeg.exe` de um build **LGPL** (ex.: BtbN `win64-lgpl`), como **executáveis separados**.
- Download por script, com versão e SHA-256 fixados; não versionado.
- Uso: `ffprobe -v error -print_format json -show_format -show_streams`; miniatura com `ffmpeg -ss … -frames:v 1`, gravando no cache (a origem só é lida).

## Consequências
- Licença LGPL-2.1+, permitida pelo CLAUDE.md. O instalador inclui o aviso de licença, a versão e o link para o código-fonte correspondente.
- Risco: a fonte do build precisa continuar disponível. O script permite trocar a URL, mantendo a checagem de hash.
