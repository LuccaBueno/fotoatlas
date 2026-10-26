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

## Fase 1 — Fundação
- [ ] Monorepo (core, app, helper, tools), `.gitignore`, README, LICENSE, CHANGELOG
  - [ ] 1.1 Branch `main`; esqueletos de `packages/fotoatlas_core` (lints, `bin/fotoatlas_cli.dart`), `app/` (`flutter create --platforms=windows`), `native/fotoatlas_helper` (sln + console + xUnit), `tools/fixtures` e `tools/scripts`
  - [ ] 1.2 Smoke test do `sqlite3`/drift com native assets no core e no app (risco R6), antes de seguir
- [ ] CI no GitHub Actions (windows-latest): analyze + testes do core, app e helper
  - [ ] 1.3 Workflow com 3 jobs (Flutter 3.47.7 fixo, .NET 10), `dart format --set-exit-if-changed` e checagem de `*.g.dart` atualizado
- [ ] Schema SQLite v1 + migrações + pragmas (WAL, synchronous=FULL, foreign_keys)
  - [ ] 1.4 Tabelas de `docs/schema-v1.md` em drift, pragmas verificados por teste, `FOTOATLAS_HOME`, recusa de banco mais novo e snapshot de schema
- [ ] Helper mínimo: listar volumes (GUID, serial, disco físico, sistema de arquivos, espaço)
  - [ ] 1.5 Host JSON-lines (`hello`, `system.*`, cancelamento, vigia do processo pai) + `volumes.list` com discos físicos e `identityConfidence`; testes xUnit
  - [ ] 1.6 `HelperClient` em Dart com reinício e timeout; testes com helper falso e com o helper real na CI
- [ ] Cadastro de fontes (pastas e unidades) com identificação independente da letra
  - [ ] 1.7 Bindings FFI mínimos (ADR 0008) + testes no Windows (caminho longo, atributos, junction)
  - [ ] 1.8 Cadastro de pasta/unidade, pontuação de identidade (ADR 0009), detector de conectividade (consulta a cada 3 s) e aviso de sobreposição de fontes
- [ ] Escaneamento de listagem (sem hash), em isolate, pausável/retomável com checkpoint
  - [ ] 1.9 Enumerador `FindFirstFileExW`, exclusões padrão, placeholders de nuvem, reparse points não seguidos, erros por pasta
  - [ ] 1.10 Worker em isolate, lotes transacionais com checkpoint (`scan_dirs`), pausar/retomar/cancelar, scan incremental e regra de ausência confirmada
  - [ ] 1.11 Teste de kill no meio do scan → retomar → contagem exata (ADR 0007)
- [ ] Gerador de fixtures sintéticos (árvore de 50 mil arquivos)
  - [ ] 1.12 `tools/fixtures`: árvore determinística (`--seed`), nomes repetidos, Unicode, pastas profundas, caminho > 260
- [ ] Telas: Início (básica) e Dispositivos
  - [ ] 1.13 Estrutura do app com navegação lateral (6 destinos), tema claro/escuro, PT-BR
  - [ ] 1.14 Dispositivos (adicionar pasta/unidade, escanear, pausar, retomar, renomear; fonte desconectada esmaecida) e Início básica; testes de widget
  - [ ] 1.15 CLI: `volumes`, `sources add|list`, `scan start|resume|status`
- [ ] Critérios: 50 mil arquivos sem travar a UI · troca de letra reconhecida · fonte desconectada visível
  - [ ] 1.16 Evidências: tempo do scan de 50 mil arquivos (CLI); latência do event loop da UI durante o scan; troca de letra (teste com volumes simulados + VHD na CI); fonte desconectada com os dados do último scan
- [ ] Tag `v0.1.0`

## Fase 2 — Conteúdo e cobertura
- [ ] Fila de hash SHA-256 em streaming, com detecção de arquivo alterado durante a leitura
- [ ] Ignorar placeholders do OneDrive
- [ ] Duplicatas exatas e níveis de cobertura (1 cópia / mesmo disco / discos diferentes)
- [ ] Backup automático do catálogo (`VACUUM INTO` com rotação)
- [ ] Tela Comparar (A × B) e painel de cobertura no Início
- [ ] Critérios da spec (seção 16, Fase 2)
- [ ] Tag `v0.2.0`

## Fase 3 — Celular (leitura)
- [ ] Helper com WPD: listar dispositivos, navegar, ler arquivos em streaming
- [ ] Escanear Android e iPhone; avisos de desbloqueio/autorização e "Manter originais"
- [ ] Comparar celular × HD
- [ ] Critérios da spec (teste real com celular só quando o usuário pedir, somente leitura)
- [ ] Tag `v0.3.0`

## Fase 4 — Metadados e Biblioteca
- [ ] Script para baixar ExifTool e FFmpeg (não versionados)
- [ ] ExifTool `-stay_open`, FFprobe, estratégia de datas e fusos, padrões de nome (WhatsApp etc.)
- [ ] Miniaturas em cache (Shell API + fallback)
- [ ] Biblioteca: grade, lista, linha do tempo, painel de detalhes
- [ ] Filtros em chips + avançado, seleção em massa, filtros salvos
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
