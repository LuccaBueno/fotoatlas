# 0004 — ExifTool para metadados de foto

- Status: aceita (2026-10-26: usuário aprovou o plano com "pode seguir direto"; Q4 sem objeção → recomendação aceita)
- Data: 2026-10-26

## Contexto
É preciso ler EXIF/XMP/QuickTime de JPEG, HEIC, RAW (dezenas de fabricantes) e vídeos, com datas e fusos corretos (spec §8).

## Alternativas consideradas
- **`package:exif` (Dart)**: só JPEG/TIFF básico; não lê HEIC nem a maioria dos RAW.
- **Exiv2** (GPL-2.0): bom para fotos, fraco para vídeo, e a licença também é GPL.
- **LibRaw/libheif via FFI**: muito trabalho e cobertura parcial de metadados.
- **Windows Property System (Shell)**: depende dos codecs instalados (HEIC exige extensão da Store) e cobre só parte dos metadados.

## Decisão
- ExifTool (Phil Harvey) como **executável separado**, em modo `-stay_open True -@ -` com lotes e saída `-json -n -G1`, sempre só leitura. Nenhuma opção de escrita é usada, e um teste garante que nenhum argumento de escrita é montado.
- Binário baixado por `tools/scripts/get-tools.ps1`, com versão e SHA-256 fixados; não versionado (`.gitignore`).

## Consequências
- **Licença**: "mesmos termos do Perl" (Artistic License 1.0 **ou** GPL-1.0+). Como roda como processo separado (agregação), não afeta a licença MIT do FotoAtlas. O instalador inclui o texto da licença e o link para o código-fonte. Essa licença não está na lista pré-aprovada do CLAUDE.md, por isso a confirmação do usuário.
- Manutenção: projeto ativo há mais de 20 anos, com lançamentos frequentes.
- Desempenho: com `-stay_open`, centenas de arquivos por segundo. Roda num worker com timeout por lote e reinício automático.
