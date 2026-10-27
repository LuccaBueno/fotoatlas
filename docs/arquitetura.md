# Arquitetura — FotoAtlas

- Versão: 1 (Etapa 0, 2026-10-26)
- Documentos relacionados: [`schema-v1.md`](schema-v1.md), [`protocolo-helper.md`](protocolo-helper.md), [`analise-spec.md`](analise-spec.md), [`adr/`](adr/)

---

## 1. Visão geral

```
┌──────────────────────────── processo do app (fotoatlas.exe) ───────────────────────────┐
│                                                                                         │
│  Isolate principal (UI Flutter)                                                         │
│   ├─ Telas (Início, Biblioteca, Dispositivos, Comparar, Tarefas, Configurações)         │
│   └─ Riverpod providers ──► FotoAtlasCore (fachada do core, Dart puro)                  │
│                                 │                                                       │
│        ┌────────────────────────┼─────────────────────────────┐                        │
│        ▼                        ▼                             ▼                        │
│  Isolate do banco         Isolates de trabalho          HelperClient ───── stdin/stdout ──┐
│  (DriftIsolate:           (scan, hash, metadados,       (reinício automático)          │  │
│   único escritor)          cópia; fila com limites)                                     │  │
│        ▲                        │                                                       │  │
│        └──── conexões drift ────┘                                                       │  │
└─────────────────────────────────────────────────────────────────────────────────────────┘  │
                                                                                             │
┌──────────────────── processo do helper (fotoatlas_helper.exe, C# .NET 10) ──────────────┐  │
│  JSON-lines: volumes/discos (Win32), celular (WPD), miniaturas (Shell)                   │◄─┘
└───────────────────────────────────────────────────────────────────────────────────────────┘

CLI (fotoatlas_cli.exe) = mesmo core, sem Flutter → testes de integração e de falha
```

Princípios de arquitetura:

1. **Core em Dart puro** (`packages/fotoatlas_core`): toda regra de negócio, toda gravação em disco e todo acesso ao banco. O app Flutter só apresenta e chama a fachada.
2. **Um único escritor no SQLite**: o `DriftIsolate`. Os isolates de trabalho se conectam a ele e nunca abrem o arquivo `.db` diretamente.
3. **Helper isolado em outro processo**: se travar, o app segue funcionando. Pelo pipe só passam mensagens, nunca bytes de arquivo (ver `protocolo-helper.md`).
4. **Gravação centralizada**: só o módulo `safe_io` grava fora da pasta do catálogo. Um teste de arquitetura falha se outro módulo usar `File.write*`, `openWrite`, `rename`, `delete` ou `copy` (seção 6).

## 2. Monorepo

```
fotoatlas/
├── packages/fotoatlas_core/
│   ├── bin/fotoatlas_cli.dart          # CLI (sources, scan, volumes, …; depois copy, recover)
│   ├── lib/fotoatlas_core.dart          # API pública (fachada + modelos)
│   ├── lib/src/
│   │   ├── catalog/      # drift: tabelas, DAOs, migrações, pragmas, backup (VACUUM INTO)
│   │   ├── platform/     # bindings FFI Win32 mínimos (ADR 0008)
│   │   ├── safe_io/      # ÚNICO módulo que grava: temp, flush, publicação sem sobrescrever
│   │   ├── sources/      # cadastro, identificação por pontuação, conectividade
│   │   ├── scan/         # enumerador, execução com checkpoint, worker em isolate
│   │   ├── hash/         # fila SHA-256 em streaming (Fase 2)
│   │   ├── coverage/     # duplicatas, cobertura, comparação A×B (Fase 2)
│   │   ├── metadata/     # ExifTool -stay_open, FFprobe, estratégia de datas (Fase 4)
│   │   ├── ops/          # diário, máquina de estados, cópia, recuperação (Fase 5)
│   │   ├── tasks/        # fila de tarefas, limites de concorrência, trava por disco
│   │   ├── helper/       # cliente JSON-lines do helper, com reinício
│   │   └── util/         # caminhos, tempo (FILETIME), UUID, logging
│   └── test/             # unit, integração (CLI) e falha (kill)
├── native/fotoatlas_helper/
│   ├── FotoAtlas.Helper/         # console app: host do protocolo + handlers
│   └── FotoAtlas.Helper.Tests/   # xUnit
├── app/                  # Flutter Windows
│   └── lib/{main.dart, app/, features/<tela>/, widgets/, l10n/}
├── tools/fixtures/       # pacote Dart: gerador determinístico de árvores e mídia sintéticas
├── tools/scripts/        # PowerShell: build, baixar ExifTool/FFmpeg (com SHA-256 fixado)
└── docs/
```

## 3. Core

### 3.1. Fachada

`FotoAtlasCore.open({required String homeDir, required HelperLauncher helper})` devolve um objeto com serviços:

- `sources`: `list()`, `watch()`, `addFolder(path)`, `addVolume(volumeGuid)`, `rename()`, `forget()` (só catálogo)
- `scans`: `start(sourceId)`, `pause()`, `resume()`, `cancel()`, `progress(scanId) → Stream`
- `devices`: `volumes() → Stream<List<VolumeInfo>>` (conectividade)
- `hashes`: `start(priority)`, `pause()`, `retryFailed()`, `status → Stream<HashStatus>` (Fase 2, §3.4.1)
- `coverage`: `report()`, `watch()`, `statesForSource()`, `duplicateGroups()` (Fase 2)
- `compare`: `compare(A, B)`, `items(A, B, lista)`, escopos salvos (Fase 2)
- `backups`: `backupNow()`, `maybeBackup()`, `list()` (Fase 2)
- Fases seguintes: `library`, `operations`, `recovery`

Toda operação longa devolve um `TaskHandle` com `Stream<Progress>`, `pause/resume/cancel` e um `Future<Result>`. A UI nunca espera uma operação longa no isolate principal.

### 3.2. Pastas de dados

| O quê | Onde | Observação |
|---|---|---|
| Catálogo | `%APPDATA%\FotoAtlas\catalog.db` (+ `-wal`, `-shm`) | spec §11.3 |
| Backups do catálogo | `%APPDATA%\FotoAtlas\backups\catalog-AAAAMMDD-HHMMSS.db` | rotação (10) |
| Miniaturas (Fase 4) | `%LOCALAPPDATA%\FotoAtlas\thumbs\` | cache descartável |
| Logs | `%LOCALAPPDATA%\FotoAtlas\logs\` | rotação; nunca enviados |
| Ferramentas (dev) | `third_party/bin/` (ignorado pelo git) | baixadas por script |

A variável de ambiente `FOTOATLAS_HOME` substitui as duas raízes (usada pela CLI e por **todos** os testes, sempre apontando para `Directory.systemTemp.createTemp`).

### 3.3. Isolates e fila de tarefas

- **DriftIsolate** (`NativeDatabase.createInBackground` / `DriftIsolate.spawn`): é o único que escreve. Todos os pragmas são aplicados na abertura.
- **TaskQueue** no isolate principal do core: agenda as tarefas em isolates de trabalho (`Isolate.run`/workers longos), com limite global (padrão: nº de núcleos − 1, no mínimo 1).
- **DiskLock**: no máximo 1 tarefa de leitura pesada (scan, hash) por **disco físico**; discos diferentes rodam em paralelo (L9). Celular conta como um "disco".
- Os workers mandam lotes (500–2.000 linhas) para o DriftIsolate, e cada lote é uma transação. O checkpoint do scan é gravado na mesma transação do lote, então retomar nunca perde nem duplica trabalho.

### 3.4. Escaneamento (Fase 1)

1. Resolve a fonte para o caminho de montagem atual (`\\?\Volume{GUID}\` + raiz relativa). Se não resolver, a fonte está **desconectada** e o scan não começa (regra 9).
2. Cria `scans` (status `running`) e semeia `scan_dirs` com a raiz `pending`.
3. O worker pega pastas `pending` e as enumera com `FindFirstFileExW(FindExInfoBasic, FIND_FIRST_EX_LARGE_FETCH)`. Cada entrada já vem com nome, tamanho, mtime/ctime (FILETIME) e atributos, sem `stat` extra. Usa prefixo `\\?\` (caminhos longos).
4. Para cada entrada:
   - reparse point (junction/symlink) → não segue; registra `reparse_point_skipped`;
   - na lista de exclusão (L10) → ignora;
   - placeholder de nuvem (atributos) → `availability = cloud_only`, sem abrir;
   - arquivo → *upsert* em `file_instances`; se tamanho+mtime mudaram, `hash_status = pending` (incremental).
5. Pasta enumerada sem erro → `scan_dirs.status = done`. Erro (acesso negado, E/S) → `error` + `scan_errors`; **os filhos dessa pasta não são marcados como ausentes**.
6. Ao final: se todas as pastas ficaram `done`, `coverage = complete`. As instâncias da fonte não vistas neste scan e cuja pasta-pai está `done` passam a `missing` (com `missing_confirmed_at`). Em scan parcial ou com erro, nada vira `missing` (regras 9 e 10).
7. Pausar = o worker termina o lote atual e para; o estado fica todo no banco. Retomar = cria um worker que continua das `scan_dirs pending`. Se o app fechar no meio, o scan fica `interrupted` e pode ser retomado.

### 3.4.1. Conferência de conteúdo, cobertura e comparação (Fase 2)

- **Fila de hash** (ADR 0010): um worker por disco físico; ordem = prioridade da comparação → tamanhos que colidem (L8) → pasta. Leitura só por `safe_io/source_reader.dart` (`GENERIC_READ`, `OPEN_EXISTING`, `FILE_FLAG_OPEN_NO_RECALL`). Tamanho e data comparados antes e depois; mudou → `changed_during_read`; erro → `error` + `hash_error`, nunca `missing`. Lotes de 32 por transação, com guarda contra scan concorrente.
- **Cobertura** (§4.6): uma consulta com CTEs; instância física deduplicada por (volume, caminho absoluto no volume); "independente" exige 2+ discos de identidade confiável. Sem hash: tamanho único → 🔴; mesmo nome+tamanho em outra fonte → 🟡; resto ⚪. `watch()` recalcula no máximo a cada 2 s (a fila grava em lotes e avisa o drift com `notifyUpdates`).
- **Comparação com escopo livre** (ADR 0011): veredito `complete` / `missing` / `incomplete` / `emptyA`; qualquer arquivo não conferido ou pasta não lida em A ou B → `incomplete`.
- **Backup do catálogo**: `quick_check` → `VACUUM INTO backups/catalog-<data>.db.tmp` → confere a cópia (só leitura) → `MoveFileExW` sem sobrescrever → rotação dos 10 mais novos (os `pre-migracao-*` nunca saem). Automático ao abrir o app se o último tiver mais de 24 h.

### 3.5. Identificação de fontes (ADR 0009)

Pontuação contra cada fonte cadastrada do tipo volume:

| Sinal | Pontos |
|---|---|
| Marcador `.fotoatlas-id` igual (se ativado) | decisivo |
| GUID do volume igual | +50 |
| Serial do volume igual | +30 |
| Disco físico com identidade confiável igual | +15 |
| Rótulo, sistema de arquivos e capacidade iguais | +5 cada |
| Serial do volume **diferente** | −40 |

- ≥ 60 e um único candidato → reconhecida automaticamente (troca de letra é transparente, porque a letra nunca é usada como identidade).
- Vários candidatos ≥ 60 → o melhor vence só com 40+ pontos de vantagem (ex.: o GUID já confirmado); senão, pergunta.
- Dois candidatos sem folga ou pontuação entre 30 e 59 → **pergunta ao usuário**.
- A letra/ponto de montagem é só informação (`last_mount_path`).
- Fonte do tipo `folder` = identidade do volume + `root_rel_path`.

### 3.6. Cópia segura (Fase 5, resumo)

Máquina de estados por item, persistida em `operation_items` (ver `schema-v1.md` §5):

```
pending → copying → copied → verifying → verified → publishing → published
    │         │         │          │           │            │
    └─────────┴─────────┴──────────┴───────────┴────────────┴──► failed | needs_attention
pending → skipped_identical   (o destino já tem conteúdo idêntico)
```

- `copying`: `CreateFileW(CREATE_NEW)` em `<destino>\.fotoatlas-tmp\<uuid>.part`; o hash da origem é calculado durante a leitura; `FlushFileBuffers`; fecha o arquivo.
- `copied`: grava `src_sha256` e `bytes_copied` (commit).
- `verifying`: relê o `.part` e calcula `dst_sha256`. Diferente → `failed` (mantém o `.part`).
- `publishing`: grava `dst_rel_path_final` **antes** de `MoveFileExW(MOVEFILE_WRITE_THROUGH)`, sem `REPLACE_EXISTING` e sem `COPY_ALLOWED`. `ERROR_ALREADY_EXISTS` → política de conflito (próximo sufixo), e o novo nome é gravado antes da nova tentativa.
- `published`: cria a `file_instance` do destino, já com `content_id` (commit).

A recuperação na inicialização é idempotente e decide **olhando o disco**, não só o diário (spec §11.2 + lacuna L1). Os testes de falha estão descritos no ADR 0007.

### 3.7. Celular (Fase 3)

Implementado (ADR 0012): `PhoneScanLister` lista pasta por pasta pelo helper (`devices.listChildren`), com o mesmo checkpoint em `scan_dirs` do scan de disco; a raiz da fonte mostra os armazenamentos como pastas (L7). `PhonePathResolver` guarda os IDs de objeto e refaz o caminho a partir da raiz quando um ID ficou velho (Android muda IDs entre sessões). Desconexão, bloqueio ou helper fora do ar → `interrupted`/`pending`, nunca `missing`. O scan e a conferência do celular rodam no isolate principal (o trabalho é do helper, outro processo). Identidade pelo serial, com o ID WPD como reserva; o celular é um disco físico próprio (`bus_type = 'mtp'`).

O helper enumera os objetos WPD e calcula o SHA-256 lendo o arquivo pelo USB, **dentro do próprio helper**. Na cópia, o helper grava direto no `.part` indicado pelo core (`devices.pullToFile`) e devolve hash e tamanho; o core relê o `.part` com o seu próprio SHA-256 em Dart. São duas implementações independentes, e só com valores iguais o item vira `verified`.

## 4. App Flutter

### 4.1. Organização

- `features/<tela>/` com `*_page.dart`, `*_controller.dart` (Notifier do Riverpod) e widgets.
- Providers por serviço do core (`sourcesProvider`, `scanProgressProvider(scanId)`…), sempre a partir de `Stream`s do core.
- Textos em PT-BR num arquivo `l10n/strings_pt_br.dart` (ARB/intl só se surgir outro idioma).
- Tema claro e escuro (Material 3) com cores semânticas para os estados de backup, sempre cor + ícone + texto.

### 4.2. Navegação

`NavigationRail` com 6 destinos (spec §3.2). Na Fase 1 só Início e Dispositivos funcionam; os outros mostram "Disponível em breve" com uma descrição curta.

### 4.3. Processo do helper

O app inicia o helper ao abrir (`HelperClient`) e o encerra ao fechar. Se ele cair, reinicia com espera crescente (1 s, 2 s, 4 s… até 30 s) e mostra um aviso discreto ("Leitura de dispositivos reiniciada").

### 4.4. Responsividade

Nenhum `await` de operação longa no isolate da UI. As listas grandes usam `ListView.builder`/grade virtualizada com paginação por *keyset* no core.

### 4.5. Telas da Fase 1

- **Dispositivos**: lista de fontes (nome, tipo, conectada/desconectada, letra atual, último scan, nº de arquivos, espaço). Ações: "Adicionar pasta", "Adicionar unidade", "Escanear", "Pausar", "Retomar", "Renomear". Fontes desconectadas aparecem esmaecidas, com "Visto pela última vez em…" e os dados do último scan.
- **Início (básica)**: total de arquivos e de fotos/vídeos (por extensão) por fonte, fontes desconectadas, scans em andamento, atalho para "Adicionar dispositivo".

### 4.5.1. Telas da Fase 2

- **Início**: painel "O que já tem backup e o que ainda não tem" com as 5 situações (cor + ícone + texto, quantidade e tamanho), progresso da conferência (pausar/continuar) e atalho para Comparar; por dispositivo, quantos arquivos só existem ali.
- **Dispositivos**: no cartão, situação de backup das fotos e vídeos da fonte, arquivos repetidos (espaço) e progresso da conferência daquela fonte.
- **Comparar**: dois editores de escopo (A e B) com entradas (dispositivo inteiro ou pasta, escolhidas pelo catálogo — funciona desconectado), filtro por tipo e escopos salvos; resultado com a pergunta "B contém todo o conteúdo de A?", motivos de "incompleto", "Conferir agora" e abas Faltam em B / Só em B / Nos dois / Não conferidos, com seleção ("N itens · X GB", "Selecionar todos os resultados"). "Copiar para B…" fica desabilitado até a Fase 5.
- **Configurações**: backup do catálogo (último, quantidade, "Fazer backup agora").
- O `ProviderScope` fica acima do `MaterialApp` para que diálogos enxerguem os providers.

### 4.6. Mapeamento dos estados de backup (resolve C2; usado a partir da Fase 2)

Para um conteúdo (ou uma instância cujo conteúdo ainda é desconhecido):

| Ícone | Rótulo | Regra |
|---|---|---|
| ⚪ | Situação desconhecida | Hash ainda não calculado e sem provável cópia; ou fonte nunca escaneada por completo. |
| 🟡 | Copiado, falta conferir | Existe instância em outra fonte com mesmo tamanho e mesmo nome, mas o conteúdo de algum dos lados ainda não foi lido por completo. |
| 🔴 | Só 1 cópia | Conteúdo conhecido (ou tamanho único no catálogo, L8) com uma só instância não ausente. |
| 🟢 | Cópia conferida | 2+ instâncias não ausentes com o mesmo SHA-256, mas no mesmo disco físico (ou com disco de identidade incerta, R1). |
| 🔵 | Backup em disco independente | 2+ instâncias com o mesmo SHA-256 em discos físicos diferentes e de identidade confiável (celular conta como disco próprio). |

- Instâncias em fontes desconectadas **contam** (regra 9), com a data em que foram vistas.
- Instâncias `missing` e `cloud_only` não contam.
- "Conferida recentemente" (verificada nos últimos 180 dias, L4) é um selo à parte, usado nos alertas do Início.

## 5. Helper nativo

Detalhes em [`protocolo-helper.md`](protocolo-helper.md). Resumo:

- Console app .NET 10, `nullable enable`, `TreatWarningsAsErrors`, código compatível com AOT.
- Handlers: `system.*`, `volumes.list` (Fase 1); `devices.*` (Fase 3); `thumbnails.get` (Fase 4).
- **Defesa em profundidade**: o helper só grava em caminhos que terminam em `.part` dentro de uma pasta `.fotoatlas-tmp`, ou no cache de miniaturas passado por argumento, e sempre com `CreateNew`.

## 6. Garantias de segurança no código

| Regra | Como é garantida |
|---|---|
| Origem só leitura | `safe_io` expõe `openSourceForRead()` (`GENERIC_READ`, `FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE`); não existe API para abrir uma origem com escrita. |
| Nada fora do `safe_io` grava | Teste de arquitetura varre `lib/src/**` e falha com `File(...).write*`, `openWrite`, `rename`, `delete`, `copy` ou `Directory.create` fora de `safe_io/` e `catalog/`. |
| Nunca sobrescrever | Publicação só por `MoveFileExW` sem `REPLACE_EXISTING`; temporários com `CREATE_NEW`; `VACUUM INTO` falha se o arquivo existe. |
| Nada é excluído | `safe_io` não tem função de exclusão de arquivos de usuário; nem o `.part` com falha é apagado (o usuário vê e decide). |
| Catálogo ≠ armazenamento | "Esquecer fonte" e "reconstruir catálogo" só mexem no banco. |
| Testes nunca tocam pastas pessoais | `FOTOATLAS_HOME` obrigatório nos testes; um helper de teste falha se o caminho não estiver em `Directory.systemTemp`. |

## 7. Caso de uso nº 1, ponta a ponta

1. Usuário conecta celular e HD → **Dispositivos** mostra os dois (HD reconhecido pela pontuação; celular pelo ID WPD).
2. Escanear os dois → listagem rápida; o Início já mostra prováveis cópias (🟡) e tamanhos únicos (🔴).
3. A fila de hash prioriza os tamanhos que colidem entre celular e HD → estados viram 🟢/🔵/🔴 definitivos.
4. **Comparar** celular × HD → "1.243 fotos do celular ainda não estão no HD" → "Ver e copiar".
5. Assistente: filtros/seleção → modelo `{ano}/{ano}-{mes}/` → prévia (quantidade, tamanho, espaço livre, conflitos, árvore) → confirmar.
6. Cópia segura item a item com diário; interrupção → recuperação ao abrir; relatório final em **Tarefas**.
