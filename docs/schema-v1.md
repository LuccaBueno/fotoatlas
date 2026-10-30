# Schema SQLite v1 — FotoAtlas

- Versão do schema: **3** (`PRAGMA user_version = 3`, gerido pelo drift). A v1 está descrita nas seções 1–6; as mudanças aditivas da v2 e da v3 estão nas seções 7 e 8.
- Data: 2026-10-26 (Etapa 0)
- Identificadores em inglês; os rótulos em PT-BR ficam na UI.

## 1. Convenções

| Item | Convenção |
|---|---|
| Datas do app (`*_at`) | `INTEGER`, milissegundos Unix UTC |
| Datas de arquivo (`mtime`, `ctime`) | `INTEGER`, **FILETIME bruto** (100 ns desde 1601, UTC), exatamente como o Win32 devolve. A comparação no scan incremental é exata e sem conversão. |
| Caminhos | `rel_path` relativo à raiz da fonte, separador `/`, **sem normalização** de Unicode nem de caixa (R8). Na I/O é convertido para `\\?\…\`. |
| Hash | `BLOB` de 32 bytes (SHA-256); hexadecimal só na UI/Detalhes |
| Enumerações | `TEXT` com `CHECK (… IN (…))` |
| IDs de fonte e operação | `TEXT` UUID v4 (estáveis em backups e exportações) |
| Demais IDs | `INTEGER PRIMARY KEY` |
| Exclusões | Nenhuma linha de instância é apagada automaticamente; ausência vira `availability = 'missing'`. |

## 2. Pragmas (aplicados em toda conexão)

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = FULL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;
PRAGMA temp_store = MEMORY;
```

Um teste verifica os pragmas efetivos após abrir. O `PRAGMA integrity_check` roda sob demanda e periodicamente (Fase 2, junto com o backup).

## 3. Migrações

- Cada passo `vN → vN+1` roda em **uma transação**; falhou, nada muda.
- Antes de qualquer migração, um backup automático `VACUUM INTO backups/pre-migracao-vN-<data>.db`.
- O app recusa abrir um banco com `user_version` **maior** que o conhecido (versão mais nova do app) e mostra uma mensagem; nunca faz *downgrade*.
- Testes: banco criado na v1 + dados → migra → confere os dados (os *snapshots* de schema do drift ficam versionados em `packages/fotoatlas_core/drift_schemas/`).
- Mudanças incompatíveis exigem aprovação do usuário (CLAUDE.md).

## 4. Tabelas

### 4.1. Metadados e configurações

```sql
CREATE TABLE app_meta (           -- catalog_id (UUID), created_at, created_by_version
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE settings (           -- preferências do usuário (JSON por chave)
  key        TEXT PRIMARY KEY,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
) WITHOUT ROWID;
```

### 4.2. Discos e fontes

```sql
CREATE TABLE physical_disks (
  id                  INTEGER PRIMARY KEY,
  serial              TEXT,                   -- pode faltar ou ser falso em gavetas USB (R1)
  model               TEXT,
  size_bytes          INTEGER,
  bus_type            TEXT,                   -- usb, sata, nvme, sd, …
  identity_confidence TEXT NOT NULL CHECK (identity_confidence IN ('reliable','weak','unknown')),
  user_confirmed      INTEGER NOT NULL DEFAULT 0,  -- usuário confirmou "é outro HD físico"
  first_seen_at       INTEGER NOT NULL,
  last_seen_at        INTEGER NOT NULL
);

CREATE TABLE sources (
  id                 TEXT PRIMARY KEY,        -- UUID
  name               TEXT NOT NULL,
  kind               TEXT NOT NULL CHECK (kind IN
                       ('external_hd','internal','usb_stick','memory_card','phone','folder')),
  -- identidade de volume (vazia para celular)
  volume_guid        TEXT,                    -- \\?\Volume{…}\
  volume_serial      INTEGER,
  volume_label       TEXT,
  filesystem         TEXT,                    -- NTFS, exFAT, FAT32, ReFS
  volume_size_bytes  INTEGER,
  physical_disk_id   INTEGER REFERENCES physical_disks(id),
  marker_id          TEXT,                    -- conteúdo do .fotoatlas-id (opcional)
  -- identidade de celular
  device_id          TEXT,                    -- ID WPD
  device_model       TEXT,
  -- raiz
  root_rel_path      TEXT NOT NULL DEFAULT '', -- relativo à raiz do volume ('' = volume inteiro)
  last_mount_path    TEXT,                    -- ex.: 'E:\' (só informativo)
  connected          INTEGER NOT NULL DEFAULT 0, -- zerado ao abrir; mantido pelo detector
  last_connected_at  INTEGER,
  total_bytes_last   INTEGER,
  free_bytes_last    INTEGER,
  created_at         INTEGER NOT NULL,
  updated_at         INTEGER NOT NULL,
  forgotten_at       INTEGER                  -- "esquecida" (oculta); dados preservados
);
CREATE INDEX ix_sources_volume_guid   ON sources(volume_guid);
CREATE INDEX ix_sources_volume_serial ON sources(volume_serial);
CREATE INDEX ix_sources_device_id     ON sources(device_id);
```

Uma fonte `folder` pode ficar dentro de outra fonte (ex.: pasta `Fotos` no HD `Backup1`). Ao cadastrar, o app avisa sobre a sobreposição. A cobertura conta **instâncias físicas únicas**, deduplicadas por (volume, caminho absoluto no volume), para que o mesmo arquivo visto por duas fontes não conte como duas cópias.

### 4.3. Escaneamentos

```sql
CREATE TABLE scans (
  id              INTEGER PRIMARY KEY,
  source_id       TEXT NOT NULL REFERENCES sources(id),
  kind            TEXT NOT NULL CHECK (kind IN ('full','incremental')),
  status          TEXT NOT NULL CHECK (status IN
                    ('running','paused','interrupted','completed','cancelled','failed')),
  coverage        TEXT CHECK (coverage IN ('complete','partial')),  -- definido ao terminar
  mount_path_used TEXT,
  started_at      INTEGER NOT NULL,
  finished_at     INTEGER,
  dirs_done       INTEGER NOT NULL DEFAULT 0,
  files_seen      INTEGER NOT NULL DEFAULT 0,
  bytes_seen      INTEGER NOT NULL DEFAULT 0,
  error_count     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX ix_scans_source ON scans(source_id, started_at DESC);

-- checkpoint + completude por pasta (spec §7: ausência só se a pasta foi escaneada sem erro)
CREATE TABLE scan_dirs (
  scan_id   INTEGER NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
  rel_path  TEXT NOT NULL,
  status    TEXT NOT NULL CHECK (status IN ('pending','done','error','excluded')),
  PRIMARY KEY (scan_id, rel_path)
) WITHOUT ROWID;
CREATE INDEX ix_scan_dirs_pending ON scan_dirs(scan_id) WHERE status = 'pending';

CREATE TABLE scan_errors (
  id        INTEGER PRIMARY KEY,
  scan_id   INTEGER NOT NULL REFERENCES scans(id) ON DELETE CASCADE,
  rel_path  TEXT NOT NULL,
  kind      TEXT NOT NULL CHECK (kind IN
              ('access_denied','path_too_long','io_error','reparse_point_skipped',
               'device_disconnected','other')),
  win32_code INTEGER,
  message   TEXT,
  at        INTEGER NOT NULL
);
```

### 4.4. Conteúdos e instâncias

```sql
CREATE TABLE contents (
  id         INTEGER PRIMARY KEY,
  sha256     BLOB    NOT NULL CHECK (length(sha256) = 32),
  size_bytes INTEGER NOT NULL,
  media_type TEXT    NOT NULL DEFAULT 'unknown'
               CHECK (media_type IN ('photo','video','raw','sidecar','other','unknown')),
  created_at INTEGER NOT NULL,
  UNIQUE (sha256, size_bytes)
);

CREATE TABLE file_instances (
  id                   INTEGER PRIMARY KEY,
  source_id            TEXT    NOT NULL REFERENCES sources(id),
  rel_path             TEXT    NOT NULL,       -- 'DCIM/Camera/IMG_1.jpg'
  dir_rel_path         TEXT    NOT NULL,       -- 'DCIM/Camera'
  name                 TEXT    NOT NULL,
  ext                  TEXT    NOT NULL,       -- minúscula, sem ponto; '' se não houver
  size_bytes           INTEGER NOT NULL,
  mtime                INTEGER,                -- FILETIME
  ctime                INTEGER,                -- FILETIME (criação no Windows)
  attributes           INTEGER,                -- FILE_ATTRIBUTE_* brutos
  content_id           INTEGER REFERENCES contents(id),   -- nulo até o hash
  hash_status          TEXT NOT NULL DEFAULT 'pending' CHECK (hash_status IN
                         ('pending','done','changed_during_read','error','not_applicable')),
  hashed_size          INTEGER,                -- tamanho/mtime observados quando o hash foi feito
  hashed_mtime         INTEGER,
  hashed_at            INTEGER,
  last_verified_at     INTEGER,                -- última vez que o conteúdo foi relido e conferiu
  availability         TEXT NOT NULL DEFAULT 'present' CHECK (availability IN
                         ('present','cloud_only','unreadable','missing')),
  integrity            TEXT NOT NULL DEFAULT 'unknown' CHECK (integrity IN
                         ('unknown','ok','changed','possibly_corrupt')),
  first_seen_scan_id   INTEGER REFERENCES scans(id),
  last_seen_scan_id    INTEGER REFERENCES scans(id),
  missing_confirmed_at INTEGER,
  UNIQUE (source_id, rel_path)
);
CREATE INDEX ix_fi_content      ON file_instances(content_id);
CREATE INDEX ix_fi_source_dir   ON file_instances(source_id, dir_rel_path);
CREATE INDEX ix_fi_size         ON file_instances(size_bytes);          -- poda por tamanho (L8)
CREATE INDEX ix_fi_hash_pending ON file_instances(source_id) WHERE hash_status = 'pending';
CREATE INDEX ix_fi_last_seen    ON file_instances(source_id, last_seen_scan_id);
CREATE INDEX ix_fi_ext          ON file_instances(ext);
```

- "Fonte desconectada" **não** é gravada em cada instância: é derivada de `sources.connected` (regra 9).
- `missing` só é gravado pela regra da arquitetura §3.4 passo 6 (scan completo e pasta-pai `done`).
- Se um arquivo `missing` reaparece no mesmo caminho, a linha volta a `present`.

### 4.5. Metadados e datas (criadas na v1, preenchidas na Fase 4)

```sql
CREATE TABLE media_metadata (
  content_id        INTEGER PRIMARY KEY REFERENCES contents(id),
  capture_utc_ms    INTEGER,           -- instante normalizado
  capture_local     TEXT,              -- 'AAAA-MM-DDTHH:MM:SS' como o usuário viveu
  tz_offset_min     INTEGER,
  date_source       TEXT CHECK (date_source IN
                      ('manual','exif_original','video_internal','filename','filesystem','none')),
  date_confidence   TEXT CHECK (date_confidence IN ('high','medium','low','none')),
  date_conflict     INTEGER NOT NULL DEFAULT 0,  -- candidatas divergem além da tolerância
  candidates_json   TEXT,              -- todas as datas candidatas com a origem
  make TEXT, model TEXT, lens TEXT,
  iso INTEGER, aperture REAL, exposure_s REAL, focal_mm REAL,
  width INTEGER, height INTEGER, orientation INTEGER,
  lat REAL, lon REAL,
  duration_ms INTEGER, fps REAL, video_codec TEXT, audio_codec TEXT, bitrate INTEGER,
  software TEXT,
  extractor         TEXT,              -- 'exiftool 13.x' / 'ffprobe 7.x'
  extracted_at      INTEGER
);
CREATE INDEX ix_mm_capture ON media_metadata(capture_utc_ms);
CREATE INDEX ix_mm_camera  ON media_metadata(make, model);

CREATE TABLE date_corrections (       -- nunca toca no arquivo (spec §8)
  id             INTEGER PRIMARY KEY,
  content_id     INTEGER NOT NULL REFERENCES contents(id),
  capture_local  TEXT NOT NULL,
  tz_offset_min  INTEGER,
  note           TEXT,
  created_at     INTEGER NOT NULL,
  superseded_at  INTEGER               -- histórico: a correção vigente tem superseded_at nulo
);
CREATE INDEX ix_dc_content ON date_corrections(content_id) WHERE superseded_at IS NULL;
```

### 4.6. Diário de operações (criado na v1, usado na Fase 5)

```sql
CREATE TABLE operations (
  id               TEXT PRIMARY KEY,   -- UUID
  kind             TEXT NOT NULL CHECK (kind IN
                     ('copy','reorganize_move','undo','restore','catalog_backup_copy')),
  status           TEXT NOT NULL CHECK (status IN
                     ('planned','confirmed','running','paused','completed',
                      'completed_with_errors','cancelled','needs_attention')),
  dest_source_id   TEXT REFERENCES sources(id),
  dest_root_rel    TEXT,
  template         TEXT,               -- ex.: '{ano}/{ano}-{mes}/'
  conflict_policy  TEXT CHECK (conflict_policy IN ('suffix','ask')),
  params_json      TEXT,               -- filtros/seleção que originaram a operação
  summary_json     TEXT,               -- relatório final
  undo_of          TEXT REFERENCES operations(id),
  created_at       INTEGER NOT NULL,
  confirmed_at     INTEGER,
  started_at       INTEGER,
  finished_at      INTEGER
);

CREATE TABLE operation_items (
  id                   INTEGER PRIMARY KEY,
  operation_id         TEXT NOT NULL REFERENCES operations(id),
  seq                  INTEGER NOT NULL,
  src_source_id        TEXT NOT NULL REFERENCES sources(id),
  src_rel_path         TEXT NOT NULL,
  src_instance_id      INTEGER REFERENCES file_instances(id),
  expected_size        INTEGER NOT NULL,
  expected_sha256      BLOB,           -- do catálogo, se conhecido
  dst_source_id        TEXT NOT NULL REFERENCES sources(id),
  dst_rel_path_planned TEXT NOT NULL,  -- após template + sanitização (L3)
  dst_rel_path_final   TEXT,           -- gravado ANTES do MoveFileExW (L1)
  tmp_rel_path         TEXT,           -- '.fotoatlas-tmp/<uuid>.part'
  original_name        TEXT,           -- se a sanitização mudou o nome
  state                TEXT NOT NULL CHECK (state IN
                         ('pending','copying','copied','verifying','verified',
                          'publishing','published','skipped_identical',
                          'failed','needs_attention','undone')),
  src_sha256           BLOB,           -- calculado durante a leitura (C3)
  dst_sha256           BLOB,
  bytes_copied         INTEGER NOT NULL DEFAULT 0,
  attempts             INTEGER NOT NULL DEFAULT 0,
  last_error_code      TEXT,
  last_error_message   TEXT,
  updated_at           INTEGER NOT NULL,
  UNIQUE (operation_id, seq)
);
CREATE INDEX ix_oi_open ON operation_items(operation_id, state)
  WHERE state NOT IN ('published','skipped_identical','undone');

CREATE TABLE operation_events (        -- auditoria append-only (tela Tarefas / exportação)
  id           INTEGER PRIMARY KEY,
  operation_id TEXT NOT NULL REFERENCES operations(id),
  item_id      INTEGER REFERENCES operation_items(id),
  at           INTEGER NOT NULL,
  from_state   TEXT,
  to_state     TEXT,
  message      TEXT
);
CREATE INDEX ix_oe_op ON operation_events(operation_id, at);
```

Toda transição de estado de um item = `UPDATE operation_items` + `INSERT operation_events` **na mesma transação**, commitada antes do próximo efeito colateral em disco.

### 4.7. Filtros, seleções, tags e integridade

```sql
CREATE TABLE saved_filters (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE,
  definition_json TEXT NOT NULL, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);

CREATE TABLE selection_sets (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE, created_at INTEGER NOT NULL
);
CREATE TABLE selection_set_items (
  set_id      INTEGER NOT NULL REFERENCES selection_sets(id) ON DELETE CASCADE,
  instance_id INTEGER NOT NULL REFERENCES file_instances(id),
  PRIMARY KEY (set_id, instance_id)
) WITHOUT ROWID;

CREATE TABLE tags (
  id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE COLLATE NOCASE
);
CREATE TABLE content_tags (
  content_id INTEGER NOT NULL REFERENCES contents(id),
  tag_id     INTEGER NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (content_id, tag_id)
) WITHOUT ROWID;

CREATE TABLE integrity_checks (
  id               INTEGER PRIMARY KEY,
  instance_id      INTEGER NOT NULL REFERENCES file_instances(id),
  operation_id     TEXT REFERENCES operations(id),
  checked_at       INTEGER NOT NULL,
  result           TEXT NOT NULL CHECK (result IN
                     ('unchanged','changed_legit','possibly_corrupt','unreadable','missing')),
  observed_sha256  BLOB,
  observed_size    INTEGER,
  observed_mtime   INTEGER
);
CREATE INDEX ix_ic_instance ON integrity_checks(instance_id, checked_at DESC);
```

## 5. Estados de um item de cópia (rótulos)

| Estado | Rótulo na UI | Final? |
|---|---|---|
| `pending` | Na fila | não |
| `copying` | Copiando | não |
| `copied` | Copiado | não |
| `verifying` | Conferindo | não |
| `verified` | Conferido | não |
| `publishing` | Finalizando | não |
| `published` | Cópia conferida | **sim** |
| `skipped_identical` | Já estava lá (idêntico) | **sim** |
| `failed` | Falhou | sim (pode tentar de novo) |
| `needs_attention` | Precisa de atenção | sim (decisão do usuário) |
| `undone` | Desfeito | **sim** |

## 6. Extensões previstas (sem quebrar a v1)

- **Item lógico** (Fase 9+): tabelas novas `media_items(id, kind)` e `media_item_members(media_item_id, content_id, role)`. Nenhuma tabela existente muda.
- **Busca por texto** (Fase 4): tabela virtual FTS5 (`tokenize='trigram'`) sobre `name`/`rel_path`/tags, mantida por triggers.
- **Miniaturas** (Fase 4): `thumbnail_cache(content_id, size, path, created_at)`.
- **Hash perceptual** (Fase 9+): `perceptual_hashes(content_id, dhash, phash)`.

Todas são migrações aditivas (novas tabelas e índices).

## 7. v2 (Fase 2, 2026-10-27) — mudanças aditivas

Migração `v1 → v2` numa transação, depois do backup `pre-migracao-v1-<data>.db`. Testada com os *snapshots* `drift_schemas/drift_schema_v1.json` e `v2.json` (`test/catalog/migration_test.dart`).

```sql
-- Motivo legível quando hash_status é 'error' ou 'changed_during_read'
-- (ex.: "Arquivo não encontrado (pode ter sido movido). Escaneie de novo.").
ALTER TABLE file_instances ADD COLUMN hash_error TEXT;

-- Escopos de comparação salvos com nome (spec §9). Só catálogo.
CREATE TABLE saved_scopes (
  id              INTEGER PRIMARY KEY,
  name            TEXT NOT NULL UNIQUE COLLATE NOCASE,   -- "Fotos do celular antigo"
  definition_json TEXT NOT NULL,                         -- {"v":1,"entries":[{"source":"<uuid>","path":"DCIM"}],"types":["photo"]}
  created_at      INTEGER NOT NULL,
  updated_at      INTEGER NOT NULL
);
```

Uso das colunas existentes pela fila de hash (ADR 0010):

| Coluna | Na Fase 2 |
|---|---|
| `hash_status` | `pending` → `done` / `changed_during_read` / `error`; `not_applicable` para somente na nuvem |
| `content_id` | preenchido junto com `done`; zerado pelo scan quando tamanho ou data mudam |
| `hashed_size`, `hashed_mtime`, `hashed_at` | o que foi observado no handle durante a leitura |
| `last_verified_at` | ainda não usado (verificação periódica, Fase 7 — ver §11) |

## 8. v3 (Fase 3, 2026-10-27) — mudanças aditivas

Migração `v2 → v3` numa transação, depois do backup `pre-migracao-v2-<data>.db`. Testada a partir dos *snapshots* v1 e v2 (`drift_schemas/drift_schema_v3.json`).

```sql
-- Celular (ADR 0012): identidade pelo serial; plataforma para os avisos (iPhone: "Manter originais").
ALTER TABLE sources ADD COLUMN device_serial   TEXT;   -- NULL se o aparelho não informa (ou só zeros)
ALTER TABLE sources ADD COLUMN device_platform TEXT;   -- android | iphone | camera | other

-- ID do objeto WPD visto no último scan. Pode não valer mais em outra sessão:
-- o core refaz o caminho a partir da raiz quando o helper responde not_found.
ALTER TABLE file_instances ADD COLUMN device_object_id TEXT;
```

Uso das colunas existentes por um celular:

| Coluna | No celular |
|---|---|
| `sources.kind` | `phone` |
| `sources.device_id` | ID WPD (PnP) atual; atualizado quando o serial reconhece o aparelho em outra porta |
| `sources.device_model` | modelo informado pelo aparelho |
| `sources.physical_disk_id` | disco próprio do celular (`bus_type = 'mtp'`, serial `phone:<serial>`; `weak` sem serial) |
| `sources.volume_*`, `last_mount_path`, `root_rel_path` | vazios (sem volume Win32) |
| `file_instances.rel_path` | começa pelo nome do armazenamento: `Armazenamento interno compartilhado/DCIM/Camera/IMG_0001.jpg` (L7) |
| `file_instances.mtime` / `ctime` | datas do WPD convertidas para FILETIME UTC; `NULL` se o aparelho não informa |
| `file_instances.attributes` | `NULL` |

## 9. v4 (Fase 4, 2026-10-29) — mudanças aditivas

Migração `v3 → v4` numa transação, depois do backup `pre-migracao-v3-<data>.db`. Testada a partir dos *snapshots* v1, v2 e v3 (`drift_schemas/drift_schema_v4.json`), com um teste de dados preservados (v3 → v4).

```sql
-- media_metadata: a data EXTRAÍDA continua em capture_* (com a origem, a confiança e as candidatas);
-- a data EFETIVA (extraída + correção de relógio + correção manual) vai para eff_*, que a linha do
-- tempo, os momentos e os filtros usam. As derivadas (ano, mês, dia, minuto do dia, dia da semana,
-- pela hora local) existem só para os filtros responderem rápido (100 mil itens < 1 s).
ALTER TABLE media_metadata ADD COLUMN body_serial TEXT;           -- nº de série do corpo (EXIF)
ALTER TABLE media_metadata ADD COLUMN meta_status TEXT NOT NULL DEFAULT 'full'
  CHECK (meta_status IN ('full','partial','error'));               -- partial = só nome e data do arquivo
ALTER TABLE media_metadata ADD COLUMN meta_error TEXT;
ALTER TABLE media_metadata ADD COLUMN eff_utc_ms INTEGER;
ALTER TABLE media_metadata ADD COLUMN eff_local TEXT;              -- 'AAAA-MM-DDTHH:MM:SS[.mmm]'
ALTER TABLE media_metadata ADD COLUMN eff_offset_min INTEGER;
ALTER TABLE media_metadata ADD COLUMN eff_source TEXT;
ALTER TABLE media_metadata ADD COLUMN eff_confidence TEXT;
ALTER TABLE media_metadata ADD COLUMN clock_correction_id INTEGER REFERENCES clock_corrections(id);
ALTER TABLE media_metadata ADD COLUMN eff_year INTEGER;
ALTER TABLE media_metadata ADD COLUMN eff_month INTEGER;
ALTER TABLE media_metadata ADD COLUMN eff_day TEXT;                -- 'AAAA-MM-DD'
ALTER TABLE media_metadata ADD COLUMN eff_minute INTEGER;          -- 0..1439
ALTER TABLE media_metadata ADD COLUMN eff_weekday INTEGER;         -- 1 = segunda … 7 = domingo
ALTER TABLE media_metadata ADD COLUMN moment_id INTEGER REFERENCES moments(id) ON DELETE SET NULL;
CREATE INDEX ix_mm_eff    ON media_metadata(eff_utc_ms);
CREATE INDEX ix_mm_ym     ON media_metadata(eff_year, eff_month);
CREATE INDEX ix_mm_moment ON media_metadata(moment_id);

-- Momentos (spec §8.3). 'edited' = nomeado, juntado ou separado: intervalo fixo, nunca desfeito por recálculo.
CREATE TABLE moments (
  id INTEGER PRIMARY KEY, kind TEXT NOT NULL CHECK (kind IN ('auto','edited')), name TEXT,
  start_utc_ms INTEGER NOT NULL, end_utc_ms INTEGER NOT NULL, item_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
);
CREATE INDEX ix_moments_start ON moments(start_utc_ms);

-- Histórico das edições de momentos.
CREATE TABLE moment_edits (
  id INTEGER PRIMARY KEY, moment_id INTEGER,
  op TEXT NOT NULL CHECK (op IN ('rename','merge','split','reset')),   -- "action" é reservado no drift
  detail_json TEXT, created_at INTEGER NOT NULL
);

-- Correção de relógio por dispositivo de captura (spec §8.2): só catálogo; desfeita marcando undone_at.
CREATE TABLE clock_corrections (
  id INTEGER PRIMARY KEY, make TEXT, model TEXT, body_serial TEXT,
  offset_ms INTEGER NOT NULL DEFAULT 0, years INTEGER NOT NULL DEFAULT 0,
  period_start_utc_ms INTEGER, period_end_utc_ms INTEGER, source_ids_json TEXT,
  note TEXT, created_at INTEGER NOT NULL, undone_at INTEGER
);
```

Regras:

- **Data efetiva** = correção manual vigente (`date_corrections`, vale acima de tudo) **ou** data extraída + correções de relógio ativas que casam (fabricante + modelo + série quando houver, período e fontes opcionais), na ordem de criação. A correção de relógio só vale para datas vindas da câmera (EXIF, vídeo, nome do arquivo), nunca para a data do sistema de arquivos.
- **Confirmar a hora** grava uma correção manual com a hora atual (sai de "Hora a confirmar").
- **Momentos:** entram os itens com `eff_confidence` alta ou média (ou manual). Itens dentro do intervalo de um momento editado ficam nele; o resto é agrupado por intervalos sem fotos maiores que `moments.gapMinutes` (configuração, padrão 120). O recálculo reaproveita o ID do momento automático com mais itens em comum.
- **Configurações** (tabela `settings`): `metadata.timezone` (padrão `America/Sao_Paulo`), `metadata.datePriority`, `moments.gapMinutes`.
- **Filtros salvos** usam a tabela `saved_filters` da v1 (`definition_json` = `LibraryFilter.toJson()`, `v: 1`).
- **Escopo da Comparar** (`saved_scopes.definition_json`): `v: 2` quando tem momentos (`"moments":[{"moment":id,"source":?}]`) ou filtro (`"filter":{…}`); escopos só com pastas continuam `v: 1`.
- **Miniaturas:** não há tabela `thumbnail_cache` (prevista na §6): o arquivo `thumbs\<2 primeiros do sha>\<sha256>_256.jpg` existe ou não; o cache é descartável.

## 10. v5 (Fase 6, 2026-10-30) — mudanças aditivas

Migração `v4 → v5` numa transação, depois do backup `pre-migracao-v4-<data>.db`. Testada a partir dos *snapshots* v1 a v4 (`drift_schemas/drift_schema_v5.json`), com um teste de dados preservados (v4 → v5: a cópia antiga continua no histórico).

```sql
-- Reorganização e Desfazer (ADR 0017). Os kinds 'reorganize_move' e 'undo', operations.undo_of e o
-- estado 'undone' já existiam desde a v1.
ALTER TABLE operation_items ADD COLUMN expected_mtime INTEGER;   -- FILETIME conferido no momento do mover
ALTER TABLE operation_items ADD COLUMN undo_of_item_id INTEGER REFERENCES operation_items(id);  -- Desfazer → item original
```

Estados de um item da reorganização: `pending → publishing → published` (ou `failed`, `needs_attention`, `skipped_identical` = "deixado onde está" por decisão, `undone` = devolvido pelo Desfazer). `publishing` grava `dst_rel_path_final` e `expected_mtime` antes do `MoveFileExW`.

## 11. v6 (Fase 7, 2026-10-30) — mudanças aditivas

Migração `v5 → v6` numa transação, depois do backup `pre-migracao-v5-<data>.db`. Testada a partir dos *snapshots* v1 a v5 (`drift_schemas/drift_schema_v6.json`), com um teste de dados preservados (v5 → v6: verificações antigas continuam, rodadas vazias).

```sql
-- Verificação de integridade (ADR 0018). Os arquivos só são lidos.
CREATE TABLE integrity_runs (
  id             INTEGER PRIMARY KEY,
  run_trigger    TEXT NOT NULL CHECK (run_trigger IN ('manual','scheduled')),
  status         TEXT NOT NULL CHECK (status IN ('running','paused','completed','cancelled')),
  paused_by_user INTEGER NOT NULL DEFAULT 0,   -- 0 = esperando (fonte, outra tarefa, app fechou)
  scope_json     TEXT NOT NULL,                -- {"label":…,"entries":[…],"olderThanDays":90,"phone":false}
  total_files    INTEGER NOT NULL,
  total_bytes    INTEGER NOT NULL,
  message        TEXT,
  created_at     INTEGER NOT NULL,
  started_at     INTEGER,
  finished_at    INTEGER
);
CREATE TABLE integrity_run_items (             -- lista fixada ao começar
  run_id      INTEGER NOT NULL REFERENCES integrity_runs(id),
  instance_id INTEGER NOT NULL REFERENCES file_instances(id),
  PRIMARY KEY (run_id, instance_id)
) WITHOUT ROWID;
ALTER TABLE integrity_checks ADD COLUMN run_id INTEGER REFERENCES integrity_runs(id);
ALTER TABLE integrity_checks ADD COLUMN expected_content_id INTEGER REFERENCES contents(id);  -- o que o catálogo esperava
ALTER TABLE integrity_checks ADD COLUMN reason TEXT;
CREATE INDEX ix_ic_run ON integrity_checks(run_id, instance_id);
```

Uso das colunas existentes:

| Coluna | Na Fase 7 |
|---|---|
| `file_instances.last_verified_at` | última verificação que releu o arquivo e conferiu (inalterado ou alterado) |
| `file_instances.integrity` | `ok` (inalterado), `changed` (editado; passa a valer o conteúdo novo), `possibly_corrupt` (com `content_id = NULL` e `hash_status = 'error'`: deixa de contar como cópia); o escaneamento volta para `unknown` quando tamanho ou data mudam, exceto `possibly_corrupt` com a mesma data |
| `integrity_checks.result` | `unchanged`, `changed_legit`, `possibly_corrupt`, `unreadable`, `missing` (nunca marca o arquivo como ausente) |
