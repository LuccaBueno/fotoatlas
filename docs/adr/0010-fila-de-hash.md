# 0010 — Fila de conferência de conteúdo (SHA-256) e `package:crypto`

- Status: aceita
- Data: 2026-10-27

## Contexto
A Fase 2 precisa do SHA-256 de cada arquivo para agrupar conteúdo idêntico, calcular cobertura e comparar escopos (spec §7, §9). Requisitos: só leitura (regra 2), não baixar placeholders de nuvem, detectar arquivo alterado durante a leitura, nunca transformar falha de leitura em "ausente" (regra 10), sobreviver a um `TerminateProcess` sem perder nem duplicar trabalho, e não disputar o mesmo HD mecânico com várias leituras (L9).

## Alternativas consideradas
- **Hash:** `package:crypto` (BSD-3, mantido pelo time do Dart, já citado na spec §4.1) × `package:pointycastle` (MIT, mais amplo, mais lento para SHA-256) × SHA-256 via `bcrypt.dll`/CNG por FFI (mais rápido, mas mais código FFI para revisar). Escolhido `crypto`: é a implementação de referência do ecossistema, sem código nativo; se a vazão virar gargalo, a troca por CNG fica isolada em `hash_engine.dart`.
- **Leitura:** `File.open()` do Dart × `CreateFileW` via FFI. O Dart não permite escolher as flags; com FFI abrimos com `GENERIC_READ`, compartilhamento total, `OPEN_EXISTING` e `FILE_FLAG_OPEN_NO_RECALL` (não traz dados da nuvem) + `FILE_FLAG_SEQUENTIAL_SCAN`. Escolhido FFI, num único módulo `safe_io/source_reader.dart`, com o teste de arquitetura conferindo as flags.

## Decisão
- `HashService` agrupa as fontes conectadas com pendências por **disco físico** (`physical_disk_id`, ou volume se desconhecido) e roda **um worker (isolate) por disco**. Fontes em scan ficam para depois (um leitor por vez).
- Ordem dentro do worker: trechos priorizados ("Conferir agora" da comparação) → tamanhos que colidem com outro arquivo (L8: tamanho único não pode ter cópia) → pasta/nome (leitura mais sequencial). A lista de ids é calculada uma vez por rodada (O(n log n)), e cada lote relê o estado das linhas.
- Por arquivo: `GetFileAttributesExW` (sem abrir) → se placeholder, `cloud_only`; abre; compara tamanho/data do handle com o catálogo (mudou desde o scan → `changed_during_read`); lê em blocos de 1 MiB; ao fim confere bytes lidos, tamanho e data de novo (mudou durante a leitura → `changed_during_read`). Erro de leitura → `error` com motivo em `hash_error`; a disponibilidade **não** muda. Se a própria fonte sumiu, o arquivo continua `pending`.
- Gravação em lotes de 32 numa transação: `INSERT … ON CONFLICT DO NOTHING` em `contents` + `UPDATE` protegido por `hash_status = 'pending' AND size_bytes = ? AND mtime IS ?` (um scan concorrente vence). Crashpoint `hash.after_batch_commit` para o teste de kill.
- Pausar = parar os workers (o estado está todo no banco). A conferência automática (app) roda depois de cada scan concluído e quando uma fonte conecta, respeitando a pausa do usuário.

## Consequências
- Licença BSD-3 (compatível). Dependência pequena e estável.
- Limitação conhecida: se outro programa reescrever o arquivo com o mesmo tamanho **e** restaurar a data de modificação durante a leitura, a mudança não é detectada. É o limite do critério da spec (tamanho + data); a verificação periódica (Fase 7) relê o conteúdo.
- Vazão de SHA-256 em Dart puro é menor que a nativa; medir na Fase 3/4 com volumes reais e trocar por CNG se necessário.
