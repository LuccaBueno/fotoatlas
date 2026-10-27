# ROADMAP — FotoAtlas

Estado do projeto. O Claude Code lê este arquivo no início de cada sessão, executa a primeira etapa não concluída e o atualiza ao final.

Legenda: `[ ]` pendente · `[~]` em andamento · `[x]` concluída · `[!]` bloqueada (ver observação)

**Modo de aprovação:** seguir direto, sem pedir aprovação por fase (usuário disse "pode seguir direto" em 2026-10-26).
<!-- Se o usuário disser "pode seguir direto", troque a linha acima por: "seguir direto, sem pedir aprovação por fase". -->

---

## Etapa 0 — Planejamento (PARAR para aprovação ao final)
- [x] Ler a especificação inteira e listar contradições, riscos e lacunas → `docs/analise-spec.md` (2026-10-26)
- [x] Arquitetura detalhada → `docs/arquitetura.md` (2026-10-26)
- [x] Schema SQLite v1 → `docs/schema-v1.md` (2026-10-26)
- [x] Protocolo do helper nativo (mensagens JSON-lines) → `docs/protocolo-helper.md` (2026-10-26)
- [x] ADRs iniciais em `docs/adr/` (0001–0009; a 0004, do ExifTool, aguarda confirmação da licença) (2026-10-26)
- [x] Plano da Fase 1 com tarefas (sub-itens abaixo) (2026-10-26)
- [x] Commit `docs: planejamento inicial` + push (2026-10-26)
- [x] **Aguardar "aprovado" do usuário** — "pode seguir direto" (2026-10-26). Q1–Q4 sem resposta → valem as recomendações: `{ano}/{ano}-{mes}/`, sufixo automático, Inno Setup, ExifTool aceito.

## Fase 1 — Fundação (concluída em 2026-10-26)
- [x] Monorepo (core, app, helper, tools), `.gitignore`, README, LICENSE, CHANGELOG
  - [x] 1.1 Branch `main`; esqueletos de `packages/fotoatlas_core` (lints, `bin/fotoatlas_cli.dart`), `app/` (`flutter create --platforms=windows`), `native/fotoatlas_helper` (sln + console + xUnit), `tools/fixtures` e `tools/scripts`
  - [x] 1.2 Smoke test do `sqlite3`/drift com native assets no core e no app (risco R6): ok em `dart test` e `flutter build windows`
- [x] CI no GitHub Actions (windows-latest): analyze + testes do core, app e helper
  - [x] 1.3 Workflow com 3 jobs (Flutter 3.47.7 fixo, .NET 10), formatação, código gerado atualizado (`build_runner` + `dart format` + `git diff`) e build do app
- [x] Schema SQLite v1 + migrações + pragmas (WAL, synchronous=FULL, foreign_keys)
  - [x] 1.4 Tabelas de `docs/schema-v1.md` em drift (`schema.drift`), pragmas verificados por teste, `FOTOATLAS_HOME`, recusa de banco mais novo (sem modificá-lo), snapshot `drift_schemas/drift_schema_v1.json`, trava de processo único
- [x] Helper mínimo: listar volumes (GUID, serial, disco físico, sistema de arquivos, espaço)
  - [x] 1.5 Host JSON-lines (`hello`, `system.*`, cancelamento, vigia do processo pai) + `volumes.list` com discos físicos e `identityConfidence`; 34 testes xUnit. Achado real: serial de NVMe quase todo zero → classificado como fraco (R1)
  - [x] 1.6 `HelperClient` em Dart com reinício, ping e timeout; testes com helper falso (queda, mudo, protocolo errado) e com o helper real
- [x] Cadastro de fontes (pastas e unidades) com identificação independente da letra
  - [x] 1.7 Bindings FFI mínimos (ADR 0008) + testes no Windows (caminho longo, atributos, junction). Achado: `GetLastError` via FFI às vezes vem 0 → nova tentativa (ADR 0008 atualizado)
  - [x] 1.8 Cadastro de pasta/unidade, pontuação de identidade (ADR 0009, com regra de folga para clones), detector de conectividade (a cada 3 s), aviso de sobreposição, confirmação de casos ambíguos
- [x] Escaneamento de listagem (sem hash), em isolate, pausável/retomável com checkpoint
  - [x] 1.9 Enumerador `FindFirstFileExW`, exclusões padrão, placeholders de nuvem (já ignorados sem abrir — antecipa parte da Fase 2), reparse points não seguidos, erros por pasta
  - [x] 1.10 Worker em isolate, lotes transacionais com checkpoint (`scan_dirs`), pausar/retomar/cancelar, scan incremental e regra de ausência confirmada (só em scan completo; pasta com erro nunca vira ausência)
  - [x] 1.11 Teste de kill no meio do scan (CLI compilada, TerminateProcess em 2 pontos) → retomar → contagem exata
- [x] Gerador de fixtures sintéticos (árvore de 50 mil arquivos)
  - [x] 1.12 `tools/fixtures`: árvore determinística (`--seed`), nomes repetidos, cópias idênticas, Unicode, pastas por ano/mês, caminho > 260
- [x] Telas: Início (básica) e Dispositivos
  - [x] 1.13 Estrutura do app com navegação lateral (6 destinos), tema claro/escuro, PT-BR
  - [x] 1.14 Dispositivos (adicionar pasta/unidade, escanear, pausar, retomar, cancelar, renomear, esquecer, confirmar unidade; desconectada esmaecida) e Início básica; 11 testes (widget + core real)
  - [x] 1.15 CLI: `volumes`, `sources add|list`, `scan start|resume|status`
- [x] Critérios: 50 mil arquivos sem travar a UI · troca de letra reconhecida · fonte desconectada visível
  - [x] 1.16 Evidências: 50 mil arquivos em 294 pastas → scan de 1,6 s (local) / 6,1 s (CI) com atraso máximo do event loop principal de 10–16 ms; troca de letra com volumes simulados **e com VHD real NTFS e FAT32 na CI**; fonte desconectada mantém contagens e último scan (core, app e VHD)
- [x] Tag `v0.1.0`

Observações da Fase 1:
- O teste "UI não trava" mede o event loop no core (mesmo isolate da UI no app) em vez de `integration_test` (ADR 0007 atualizado).
- Pendente para fases futuras: helper ainda não é copiado junto do app no build (o app o encontra na pasta de build do `native/` em desenvolvimento) — empacotamento na Fase 8.

## Fase 2 — Conteúdo e cobertura (concluída em 2026-10-27)
- [x] Fila de hash SHA-256 em streaming, com detecção de arquivo alterado durante a leitura (2026-10-27)
  - [x] Leitura só por `safe_io/source_reader.dart` (FFI, `GENERIC_READ` + `OPEN_EXISTING` + `FILE_FLAG_OPEN_NO_RECALL`), flags conferidas pelo teste de arquitetura
  - [x] Um worker por disco físico, prioridade (comparação → tamanhos que colidem → pasta), lotes transacionais com guarda contra scan concorrente, pausar/continuar, automática após scan e ao conectar (ADR 0010)
  - [x] Mudou depois do scan / durante a leitura (tamanho e data) → `changed_during_read`; erro → `error` + motivo, nunca `missing`; fonte que sai fica `pending`
  - [x] Kill no meio da conferência (CLI, crashpoint `hash.after_batch_commit`) → retomar sem duplicar
- [x] Ignorar placeholders do OneDrive: a fila só lê `present` e checa os atributos antes de abrir (2026-10-27)
- [x] Duplicatas exatas e níveis de cobertura (1 cópia / mesmo disco / discos diferentes), com dedup de fontes sobrepostas, disco fraco nunca independente e poda por tamanho (L8) (2026-10-27)
- [x] Backup automático do catálogo (`VACUUM INTO` → conferência → publicação sem sobrescrever → rotação de 10) (2026-10-27)
- [x] Comparação com **escopo livre** (requisito ajustado em 2026-10-27, spec §3.2 e §9; ADR 0011)
  - [x] Escopo = uma ou mais pastas/subpastas e/ou fontes inteiras + filtro opcional por tipo (data etc. na Fase 4)
  - [x] "B contém todo o conteúdo de A?" → "Sim, 100%" / "Faltam N arquivos (X GB)" com a lista pronta para seleção; também "Só em B" e "Nos dois"
  - [x] Sempre por conteúdo (SHA-256), ignorando nomes e pastas; hash pendente/erro/nuvem ou pasta ilegível em qualquer lado → "Resultado incompleto" (nunca "100%") + "Conferir agora"
  - [x] Escopos salvos com nome (tabela `saved_scopes`, migração aditiva v1 → v2 com teste)
  - [x] Teste: A = pasta1 + pasta2, B = pasta3, nomes diferentes e conteúdo parcial (core, CLI e app com core real)
- [x] Tela Comparar (montar escopos A e B, escopos salvos, resultado e listas com seleção) e painel de cobertura no Início; cobertura por fonte em Dispositivos; backup em Configurações (2026-10-27)
- [x] Critérios da spec (seção 16, Fase 2) — evidências no CHANGELOG
- [x] Teste do usuário (2026-10-27): A = pasta1 + pasta2 × B = pasta3 → Faltam 2 / Só em B 1 / Nos dois 2; escopo salvo OK
- [x] Ajustes de interface pedidos no teste (antes da tag) (2026-10-27)
  - [x] Seletor da Comparar: botão "Adicionar nova pasta/dispositivo…" que cadastra e escaneia sem sair da tela + dica "Não encontrou? Ela precisa ser adicionada e escaneada primeiro"
  - [x] Plural/concordância em todos os contadores ("1 arquivo com só 1 cópia", "4 cópias conferidas")
  - [x] Caminhos nas listas com um só separador ("HD_antigo › pasta2 › notas.txt")
  - [x] Resumo da comparação com arquivos × conteúdos ("A: 5 arquivos (4 conteúdos diferentes, 1 repetido)")
- [ ] Tag `v0.2.0` — **depois dos ajustes, com CI verde**

Observações da Fase 2:
- Antes da fase: o teste de VHD passou a conferir o estado real pelo Windows; isso mostrou que o `detach vdisk` do diskpart deixava o disco anexado. Trocado por `Dismount-DiskImage`, sem tolerância; 3/3 verdes na CI. Actions atualizadas para Node 24 (checkout@v7, setup-dotnet@v6).
- "Copiar para B…" aparece desabilitado na Comparar: a cópia segura é a Fase 5.
- Limitação registrada (ADR 0010): reescrita com mesmo tamanho **e** data restaurada durante a leitura não é detectável por tamanho+data; a Fase 7 relê o conteúdo.
- `last_verified_at` e o selo "conferida recentemente" ficam para a Fase 7.
- Duplicatas: há a API (`duplicateGroups`) e o espaço repetido por fonte; uma tela de navegação por grupos entra com a Biblioteca (Fase 4).

## Fase 3 — Celular (leitura)
- [ ] Helper com WPD: listar dispositivos, navegar, ler arquivos em streaming
- [ ] Escanear Android e iPhone; avisos de desbloqueio/autorização e "Manter originais"
- [ ] Comparar celular × HD
- [ ] Critérios da spec (teste real com celular só quando o usuário pedir, somente leitura)
- [ ] Tag `v0.3.0`

## Fase 4 — Metadados e Biblioteca
- [ ] Script para baixar ExifTool e FFmpeg (não versionados)
- [ ] ExifTool `-stay_open`, FFprobe, estratégia de datas e fusos, padrões de nome (WhatsApp etc.)
- [ ] **Data e hora da captura como cidadã de primeira classe** (requisito ajustado em 2026-10-27, spec §3.2, §8.1–8.3, §10)
  - [ ] Hora até os segundos (+ subsegundos), instante UTC + hora local, origem e confiança (alta/média/baixa); "hora incerta" sinalizada
  - [ ] Linha do tempo única intercalando todos os dispositivos pela hora real (ano → mês → dia → momento)
  - [ ] Momentos automáticos por intervalo sem fotos (padrão 2 h, configurável); baixa confiança fica em "Hora a confirmar"
  - [ ] Nomear, juntar e separar momentos (só catálogo), preservados em recálculos
  - [ ] Correção de relógio por dispositivo de captura ("+1 h", "ano errado"), com prévia, só no catálogo, reversível
  - [ ] Momento como escopo na Comparar (entrada nova no JSON do escopo, `v: 2`) e como filtro
  - [ ] Schema: tabelas novas para momentos, edições de momentos e correções por dispositivo (migração aditiva v2 → v3)
- [ ] Miniaturas em cache (Shell API + fallback)
- [ ] Biblioteca: grade, lista, linha do tempo, painel de detalhes
- [ ] Filtros em chips + avançado, seleção em massa, filtros salvos — incluindo faixa de horário, período do dia, dia da semana, momento e confiança da hora
- [ ] Critérios da spec (100 mil itens, < 1 s)
- [ ] Tag `v0.4.0`

## Fase 5 — Cópia segura
- [ ] Diário de operações e máquina de estados por item
- [ ] Protocolo de cópia (temp no destino, flush, rehash, publicação sem sobrescrever)
- [ ] Recuperação idempotente na inicialização
- [ ] Assistente "Copiar o que falta" (unidades e celular), checagem de espaço e FAT32
- [ ] Testes de falha matando o processo em cada estado
- [ ] Tela Tarefas (fila + histórico + exportação)
- [ ] Tag `v0.5.0`

## Fase 6 — Reorganização
- [ ] Modelos de estrutura e prévia em árvore antes → depois
- [ ] Modelo com momento: `{ano}/{ano}-{mes}-{dia} {momento}/` (momento sem nome → início do momento; hora a confirmar → pasta própria; sanitização de nomes), variáveis de hora usando as correções do catálogo (spec §12)
- [ ] Movimentação no mesmo volume via diário + Desfazer
- [ ] Critérios da spec
- [ ] Tag `v0.6.0`

## Fase 7 — Integridade periódica
- [ ] Verificação agendada, classificação (inalterado / alterado / possivelmente corrompido)
- [ ] Apontar outras cópias conferidas e restaurar via cópia segura
- [ ] Tag `v0.7.0`

## Fase 8 — Distribuição
- [ ] Instalador com ExifTool e FFmpeg, preservando o catálogo em atualizações
- [ ] Teste em máquina limpa, documentação de usuário
- [ ] Release `v1.0.0` no GitHub

## Fase 9+ — Avançados
- [ ] Item lógico (RAW+JPEG, Live Photos) · duplicatas visuais · mapa · IA local · Google Takeout

---

## Registro de sessões
<!-- O Claude Code adiciona uma linha por sessão: data — etapa — resumo -->
- 2026-10-26 — Etapa 0 — Spec analisada (8 contradições, 12 riscos, 15 lacunas); arquitetura, schema v1, protocolo do helper, ADRs 0001–0009 e plano da Fase 1. Aguardando "aprovado" e as respostas de Q1–Q4.
- 2026-10-26 — Fase 1 — Fundação concluída: catálogo v1, helper com volumes.list, fontes independentes da letra, scan com checkpoint em isolate, CLI, fixtures, telas Início/Dispositivos, CI verde (incl. kill e VHD NTFS/FAT32). Tag v0.1.0.
- 2026-10-27 — Antes da Fase 2 + Fase 2 — CI: causa dos runs 40275882141 (bin/ não versionado) e 40276396430 (VHD); desanexo trocado por Dismount-DiskImage após o reforço mostrar disco ainda anexado; 3/3 verdes; actions em Node 24. Requisito de comparação com escopo livre na spec. Fase 2 implementada (hash, cobertura, duplicatas, comparação, escopos salvos, backup do catálogo, telas); tag v0.2.0 aguarda o teste do usuário.
- 2026-10-27 — Ajuste de requisito (sem implementação) — data e hora da captura até segundos, linha do tempo única, momentos (nomear/juntar/separar, escopo e filtro), filtros de horário/período/dia da semana, correção de relógio por dispositivo com prévia, hora de baixa confiança fora dos momentos automáticos, modelo {ano}/{ano}-{mes}-{dia} {momento}/: spec §3.2, §8, §9, §10, §12, §16 e ROADMAP das Fases 4 e 6.
- 2026-10-27 — Teste do usuário da Fase 2 aprovado (Faltam 2 / Só em B 1 / Nos dois 2). Ajustes de interface: adicionar e escanear pelo seletor da Comparar, plural nos contadores, caminhos com um só separador, resumo arquivos × conteúdos. Tag v0.2.0. Fase 3 **não iniciada**: aguarda o usuário.
