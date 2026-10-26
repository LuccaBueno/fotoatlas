# 0002 — SQLite via `sqlite3` + `drift`

- Status: aceita
- Data: 2026-10-26

## Contexto
O catálogo precisa ser durável (WAL, `synchronous=FULL`), transacional, com migrações versionadas e consultas rápidas em mais de 100 mil itens, funcionando no Flutter e na CLI em Dart puro.

## Alternativas consideradas
- **`sqlite3` puro** (SQL escrito à mão): menos dependências e controle total, mas sem migrações tipadas, sem `DriftIsolate` (escritor único entre isolates) e sem consultas reativas para a UI.
- **`sqflite`/`sqflite_common_ffi`**: pensado para mobile, API simples, sem migrações tipadas.
- **Isar/ObjectBox/Hive**: não são SQLite; perderíamos SQL, FTS5, `VACUUM INTO` e `integrity_check`.

## Decisão
- `sqlite3` (MIT; o SQLite é domínio público), com a biblioteca nativa empacotada via build hooks.
- `drift` (MIT) + `drift_dev`/`build_runner` (dev) para tabelas, DAOs, migrações com *snapshots* de schema e streams reativos.
- Um único `DriftIsolate` escritor; os workers se conectam a ele.
- Pragmas aplicados ao abrir: `journal_mode=WAL`, `synchronous=FULL`, `foreign_keys=ON`, `busy_timeout=5000`.
- Os arquivos gerados (`*.g.dart`) são **versionados**; a CI roda o `build_runner` e falha se houver diferença.

## Consequências
- Risco R6 (native assets do `sqlite3` no Flutter Windows e na CI): é a primeira verificação da Fase 1.
- As versões exatas ficam fixadas no `pubspec.lock`, que é versionado (app e CLI são aplicações).
- Manutenção: drift e sqlite3 são ativos e mantidos pelo mesmo autor.
