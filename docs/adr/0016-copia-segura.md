# 0016 — Cópia segura: diário por item, recuperação pelo disco e o que pode ser apagado

- Status: aceita
- Data: 2026-10-29

## Contexto
A Fase 5 é a primeira que grava arquivos do usuário fora da pasta do catálogo (spec §2 regras 3–7 e 11, §11, §13). O protocolo por arquivo e os estados já estavam no planejamento (`docs/arquitetura.md` §3.6, `docs/schema-v1.md` §4.6, lacunas C3 e L1 de `docs/analise-spec.md`). Faltava decidir como cada passo vira código, o que acontece em cada falha e o que o FotoAtlas pode apagar.

## Decisão

### Onde fica cada coisa
- `safe_io/dest_writer.dart` — única escrita de conteúdo do core: `PartWriter` abre com `CreateFileW(GENERIC_WRITE, sem compartilhamento, CREATE_NEW)` só em caminhos `*.part` dentro de uma pasta `.fotoatlas-tmp`; `WriteFile`, `SetFileTime` (data de modificação da origem) e `FlushFileBuffers`. `ensureDirectory` cria pastas (`CreateDirectoryW`, nunca substitui). `deleteOwnPart` é o **único** `DeleteFileW` e recusa qualquer caminho que não seja um `.part` em `.fotoatlas-tmp`.
- `safe_io/move_no_replace.dart` — publicação com `MoveFileExW(MOVEFILE_WRITE_THROUGH)`, sem `REPLACE_EXISTING` e sem `COPY_ALLOWED` (o `.part` fica no mesmo volume do destino, na raiz da fonte de destino).
- `ops/` — prévia (`copy_planner.dart`), bombeamento de bytes em isolate (`copy_pump.dart`), executor + recuperação + consultas (`copy_service.dart`), nomes e modelos (`names.dart`).
- O teste de arquitetura falha se `CreateFileW`, `WriteFile`, `DeleteFileW`, `CreateDirectoryW`, `SetFileTime`, `MoveFileExW` ou os wrappers acima aparecerem fora da lista; confere `CREATE_NEW` e que a checagem de caminho vem antes do `DeleteFileW`.

### Protocolo por item
`pending → copying → copied → verifying → verified → publishing → published` (ou `failed`, `needs_attention`, `skipped_identical`). Cada transição é `UPDATE … WHERE state = <anterior>` + `INSERT operation_events` numa transação, commitada **antes** do próximo efeito no disco.

1. Checagens: origem conectada (celular desbloqueado), FAT32 × 4 GB, espaço livre ≥ tamanho + 64 MB.
2. `copying` grava `tmp_rel_path` (UUID novo a cada tentativa). Disco: lê a origem só para leitura e calcula o SHA-256 durante a leitura; confere tamanho/data antes e depois. Celular: `devices.pullToFile` no helper (grava, calcula o SHA-256 e faz flush).
3. `copied` grava `src_sha256` (C3: a recuperação não precisa reler a origem). Se o catálogo já conhecia o conteúdo e o hash mudou, o item falha (`source_changed`).
4. `verifying` relê o `.part` (core, em Dart — implementação independente do helper no caso do celular). Diferente: `failed` e **o `.part` fica para diagnóstico** (spec §11.1, passo 6).
5. `publishing` grava `dst_rel_path_final` antes do move (L1). Nome ocupado: sufixo `_1`, `_2`… (gravado antes da nova tentativa) ou, com a política "perguntar", `needs_attention` com o `.part` conferido esperando a decisão. Se o arquivo que ocupa o nome tem o mesmo conteúdo, `skipped_identical` (não duplica).
6. `published` registra a `file_instance` do destino já com o conteúdo conferido, na mesma transação.

### Recuperação (ao abrir o core e antes de continuar uma operação)
Decide **olhando o disco**: `copying` → descarta o `.part` (nosso) e volta para `pending`; `copied`/`verifying`/`verified` → relê o `.part`: igual ao hash gravado, publica; senão refaz; `publishing` → `.part` existe: confere e publica (nome ocupado → próximo sufixo); só o destino existe: confere o hash e registra; nenhum dos dois ou hash diferente → `needs_attention`. Operações `running` viram `paused` ("interrompida"). Destino desconectado: nada é tocado. Rodar de novo não muda nada (sem evento novo, sem `updated_at` novo).

### O que pode ser apagado
Só o `.part` do próprio FotoAtlas, registrado no diário e **nunca publicado**: cópia interrompida, pausada, que falhou na leitura da origem ou que vai ser refeita na recuperação. Nunca: arquivo publicado, arquivo do usuário, `.part` de conferência que não bateu (diagnóstico), arquivo desconhecido na pasta temporária (listado na tela Tarefas, spec §11.2). Cancelar não apaga o que já foi copiado.

### Falhas
- Falta de espaço (checagem prévia ou gravação que falha com o disco realmente cheio — medido no disco, porque o código de erro nem sempre é `ERROR_DISK_FULL`): descarta o parcial, item volta para `pending`, operação `paused` com o motivo.
- Origem: pasta renomeada → item `failed` ("não está mais na origem"), sem marcar o arquivo como ausente no catálogo (regra 10); a unidade inteira saiu → `paused` (regra 9). Celular desconectado ou helper fora do ar → `paused`; continuar refaz o arquivo, procurando o objeto pelo caminho se o ID ficou velho.
- Pausa e fechamento: o arquivo do momento é abandonado (parcial descartado) e volta para `pending`.

### Testes de falha (ADR 0007)
CLI compilada morta em 11 pontos (antes/depois de cada commit de estado, no meio da escrita do `.part`, entre `publishing` e o move, entre o move e `published`) e no meio da própria recuperação; o teste confere o estado do diário e do disco no momento da morte, roda a recuperação 3 vezes (2ª e 3ª sem nenhuma mudança no diário, no catálogo e no disco) e termina a cópia: nada perdido, nada sobrescrito, origem intacta, desconhecido na pasta temporária intacto. VHD (CI): FAT32 real com arquivo de 4 GB + 1 MB e disco que enche no meio.

## Consequências
- Limitação (R3): matar o processo não simula queda de energia nem disco USB que mente sobre o flush; a mitigação é `FlushFileBuffers`, `MOVEFILE_WRITE_THROUGH`, `synchronous=FULL` e a recuperação que relê o que está no disco (`docs/backup-e-restauracao.md`).
- Celular nunca é destino (o helper não tem escrita no aparelho).
- Os modelos de pasta da Fase 5 são um subconjunto (`{ano}/{ano}-{mes}`, `{ano}/{ano}-{mes}-{dia}`, `{tipo}/{ano}`, estrutura original, tudo numa pasta); `{momento}` e a prévia em árvore "antes → depois" entram com a reorganização (Fase 6).
- A verificação dupla custa uma releitura completa de cada arquivo no destino (segurança antes de desempenho, regra 1).
