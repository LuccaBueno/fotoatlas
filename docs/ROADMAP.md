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

## Fase 2 — Conteúdo e cobertura
- [ ] Fila de hash SHA-256 em streaming, com detecção de arquivo alterado durante a leitura
- [ ] Ignorar placeholders do OneDrive (scan já os cataloga como `cloud_only` sem abrir; falta a fila de hash respeitar isso)
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
- 2026-10-26 — Fase 1 — Fundação concluída: catálogo v1, helper com volumes.list, fontes independentes da letra, scan com checkpoint em isolate, CLI, fixtures, telas Início/Dispositivos, CI verde (incl. kill e VHD NTFS/FAT32). Tag v0.1.0.
