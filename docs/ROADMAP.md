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
- [x] Tag `v0.2.0` em 045d6f1 (2026-10-27), CI run 40562944176 verde

Observações da Fase 2:
- Antes da fase: o teste de VHD passou a conferir o estado real pelo Windows; isso mostrou que o `detach vdisk` do diskpart deixava o disco anexado. Trocado por `Dismount-DiskImage`, sem tolerância; 3/3 verdes na CI. Actions atualizadas para Node 24 (checkout@v7, setup-dotnet@v6).
- "Copiar para B…" aparece desabilitado na Comparar: a cópia segura é a Fase 5.
- Limitação registrada (ADR 0010): reescrita com mesmo tamanho **e** data restaurada durante a leitura não é detectável por tamanho+data; a Fase 7 relê o conteúdo.
- `last_verified_at` e o selo "conferida recentemente" ficam para a Fase 7.
- Duplicatas: há a API (`duplicateGroups`) e o espaço repetido por fonte; uma tela de navegação por grupos entra com a Biblioteca (Fase 4).

## Fase 3 — Celular (leitura) (concluída em 2026-10-28)
- [x] Helper com WPD: listar dispositivos, navegar, ler arquivos em streaming (2026-10-27)
  - [x] Interop COM próprio só de leitura (ADR 0012): métodos de escrita/exclusão não declarados, abertura com `GENERIC_READ`, pendrives (WPD-MSC) filtrados
  - [x] `devices.list` (status ok/bloqueado/sem autorização, armazenamentos), `devices.listChildren` (lotes), `devices.hashObject` (SHA-256 no helper, mudança durante a leitura)
  - [x] Backend simulado `--fake-devices` (testes e demonstração sem celular), com "desplugar" e IDs instáveis
- [x] Escanear Android e iPhone; avisos de desbloqueio/autorização e "Manter originais" (2026-10-27)
  - [x] Schema v3 aditivo (`file_instances.device_object_id`, `sources.device_serial`, `sources.device_platform`)
  - [x] Cadastro de celular (identidade pelo serial; ID WPD como reserva), conectividade, celular como disco próprio
  - [x] Scan por pasta com checkpoint; ID de objeto re-resolvido pelo caminho; desconexão → `interrupted`, nunca ausência
  - [x] Conferência (hash) pelo helper, um leitor por celular
- [x] Comparar celular × HD (core, CLI com helper real e app) (2026-10-27)
- [x] App: "Adicionar celular", avisos, cartão do celular; CLI `devices` e `sources add-phone`; fixture de celular simulado
- [x] Critérios da spec: com celular **simulado** pelo helper real, "listar fotos que não estão no HD" e "desconexão durante o scan não corrompe o catálogo" provados; com celular **real**, scan e conferência de DCIM/Camera sem erros (evidências no CHANGELOG) (2026-10-28)
- [x] Teste do usuário com celular simulado (2026-10-28): Pixel × HD → Faltam 3 / Só em B 1 / Nos dois 3
- [x] Ajustes pedidos no teste (2026-10-28)
  - [x] Testes e `run-app.ps1` limpam as próprias pastas de `%TEMP%` (teste falha se sobrar); `tools/scripts/clean-temp.ps1`
  - [x] 🟢 em vez de 🔵 no Pixel × HD: confirmado que é o SSD C: (NVMe, serial zerado → identidade fraca, R1); o app agora mostra "não dá para confirmar que estão em discos diferentes"
- [x] Celular real, **somente leitura** (Samsung Galaxy M54, Android, 2026-10-28): `devices` → pronto, "Armazenamento interno"; scan só de DCIM/Camera → 6.596 arquivos (106,8 GB), 0 erros; conferência → 6.596 conferidos, 0 erros, em 47 min. Achado e corrigido: stream WPD não liberado (0x800700AA) — ADR 0012 atualizado
- [x] Tag `v0.3.0` (2026-10-28)

Observações da Fase 3:
- Não existe celular virtual no Windows: a CI cobre o interop WPD real só com objetos em memória do Windows; navegação e leitura num aparelho real dependem do teste do usuário (ADR 0012).
- `devices.enumerate` (recursivo) virou `devices.listChildren` (por pasta), para o checkpoint por pasta.
- Sem data do aparelho, o incremental do celular usa tamanho + caminho (não refaz o hash de tudo pelo USB).
- A migração da Fase 4 passa a ser v3 → v4 (a v3 foi usada aqui).
- Novo: scan de uma pasta só (`scan start FONTE --folder P`), parcial e honesto na comparação. Chegou ao app nos ajustes antes da Fase 4.
- A primeira conferência real expôs que os testes do helper não cobriam a liberação de objetos COM; o stream agora é ponteiro cru com teste próprio. Os demais objetos (`IPortableDeviceValues` etc.) seguem no wrapper gerado: não prendem o aparelho, mas só são liberados pelo coletor de lixo.

## Ajustes de interface antes da Fase 4 (concluídos em 2026-10-28)
- [x] Um botão só, **"Adicionar dispositivo"** (Dispositivos e seletor da Comparar), no lugar de "Adicionar pasta", "Adicionar celular" e "Adicionar unidade": janela que lista celulares (pronto/bloqueado/falta permitir), unidades (HD, SSD, pendrive, cartão; as já cadastradas marcadas) e "Escolher uma pasta…" (spec §3.2)
- [x] Scan por pasta no app: "Escanear" pergunta "Tudo" ou "Só algumas pastas" (árvore lida do dispositivo na hora, só leitura), com tamanho estimado pelo último escaneamento; várias pastas num scan só (core `scans.start(fonte, folders: [...])`, CLI `--folder` repetido) (spec §3.2 e §7)
- [x] Cartão mostra quais pastas já foram escaneadas (e quando) e que o resto ainda não foi; o próximo "Escanear" sugere as mesmas pastas; "Retomar" continua o scan pausado com as mesmas pastas
- [x] Testes: core (várias pastas, ausência só dentro delas, retomar com outras pastas recusado, listar pastas de unidade e de celular sem catalogar nada, unidades para cadastrar) e app (janela única, árvore com tamanho e seleção, cartão com pastas escaneadas, "Retomar")

Observações:
- Sem migração de schema: as pastas de partida de cada scan saem de `scan_dirs` (pasta cuja mãe não está no scan).
- Pasta nunca escaneada aparece com "tamanho desconhecido": no celular, estimar exigiria percorrer a pasta inteira pelo USB, que já é o próprio scan.
- O tipo da unidade na janela vem do barramento (USB → "HD externo"; SD → "Cartão de memória"; removível → "Pendrive"; senão "Disco interno").

## Correções do teste dos ajustes (concluídas em 2026-10-29)
- [x] Teste do usuário dos ajustes de interface: OK
- [x] **Bug: o app não fechava pelo X.** Causa: `core.close()` esperava o `close()` de streams com ouvinte pausado (o Riverpod pausa as telas fora de vista), o que nunca termina; somavam-se esperas sem prazo (10 s por worker, backup, catálogo, helper preso numa leitura WPD). Correção: encerramento por etapas com prazo, helper finalizado se não sair, tela "Encerrando com segurança…" com o que falta, saída garantida em até 12 s (ADR 0013)
- [x] Testes: core (ouvintes pausados, inclusive `watch()` do banco — falham com o código antigo; celular travado no scan e na conferência → fecha e retoma exato; scan + hash em isolates; helper falso travado é finalizado; fechar e reabrir o catálogo 20 vezes) e app (fechar com a conferência travada); 3/3 verdes em sequência
- [x] CI do primeiro push vermelha (run 40812080833): reabrir o catálogo logo após fechar dava "database is locked" — `shutdownAll()` do drift responde antes de fechar o SQLite, e `db.close()` esperava `watch()` pausados. Corrigido no `Catalog.close()` (ADR 0013). Também: teste de desempenho de 100 mil arquivos instável por rodar em paralelo com o de 50 mil → agora em sequência
- [x] Dispositivos vazia: "Adicionar dispositivo" só no centro (o do topo aparece quando há dispositivos)

## Correções do teste de fechamento com celular real (concluídas em 2026-10-29)
- [x] Teste do usuário: fechar durante a conferência do celular real → "Encerrando com segurança…" e o app fechou, mas o terminal mostrou `Unhandled Exception: HelperException(helper_crashed)`
- [x] Causa: `HelperClient.call()` registrava o pedido antes de escrever no stdin; com o stdin já fechado (encerrando), o pedido ficava órfão e falhava solto quando o helper era finalizado. O pedido tardio vem da conferência tentando achar o arquivo de novo depois que a leitura presa falha. Corrigido; durante o encerramento nada novo vai ao helper (ADR 0013, atualização)
- [x] Teste que reproduz com o `HelperClient` real e um helper falso que trava como o WPD (falha com a mensagem exata no código antigo); queda do helper fora do encerramento: no scan (interrompido, retoma exato) e na conferência (pendente sem erro, continua sozinha), helper reinicia e a interface avisa
- [x] Pergunta antes de fechar com tarefas em andamento ("Continuar trabalhando" padrão / "Fechar mesmo assim"); sem tarefas, fecha direto
- [x] CI vermelha em 2 runs (40820342568, 40823014535): testes de encerramento estouravam o limite de 30 s **só na CI**, por rodarem junto com a geração dos 50 mil arquivos (119,7 s nessa rodada, ~78 s aqui), que satura o disco do runner (gravações com `synchronous=FULL` esperando o disco); com o teste estourado, o corpo seguia rodando durante a limpeza e a pasta ficava presa. Não reproduziu aqui nem com CPU sufocada. Correção: testes de desempenho (tag `perf`) rodam sozinhos depois dos outros na CI; diagnóstico novo (arquivos que sobram, etapas do encerramento que estouram o prazo)
- [x] Conferência do celular grava cada arquivo na hora (antes: lotes de 32, perdidos ao fechar no meio). Retomar exato confirmado em teste (lê 3, fecha, reabre → 3 continuam, só o resto é lido) e com o helper real (celular simulado com leitura lenta: 3 ao fechar, 3 ao reabrir, os 5 restantes em 3,6 s ≈ 5 leituras)

## Ajustes do modo demonstração (concluídos em 2026-10-29)
- [x] Teste do usuário do fechamento: pergunta, "Continuar trabalhando", "Fechar mesmo assim" e "Encerrando…" OK, sem exceção. Achado: com `-Demo` a conferência não continuou ao reabrir — o catálogo temporário é apagado ao fechar — mas os textos prometiam "continua de onde parou"
- [x] Faixa fixa "Modo demonstração — tudo será descartado ao fechar" (`FOTOATLAS_DEMO`, definido pelo `run-app.ps1`); pergunta ao fechar e "Encerrando…" avisam que nada será mantido nesse modo
- [x] `run-app.ps1 -DemoPersistente`: sempre `%TEMP%\fotoatlas_demo_persistente`, não apagada ao fechar (só pelo `clean-temp.ps1`); com `-CelularSimulado`, celulares gerados uma vez e Pixel com leitura lenta (3 s por arquivo) para fechar no meio da conferência
- [x] Testes: modo pelo ambiente, textos da pergunta nos 3 modos, faixa, e fechar com core real com e sem demonstração

## Fase 4 — Metadados e Biblioteca (concluída em 2026-10-29)
- [x] Script para baixar ExifTool e FFmpeg (não versionados)
- [x] ExifTool `-stay_open`, FFprobe, estratégia de datas e fusos, padrões de nome (WhatsApp etc.)
- [x] **Data e hora da captura como cidadã de primeira classe** (requisito ajustado em 2026-10-27, spec §3.2, §8.1–8.3, §10)
  - [x] Hora até os segundos (+ subsegundos), instante UTC + hora local, origem e confiança (alta/média/baixa); "hora incerta" sinalizada
  - [x] Linha do tempo única intercalando todos os dispositivos pela hora real (ano → mês → dia → momento)
  - [x] Momentos automáticos por intervalo sem fotos (padrão 2 h, configurável); baixa confiança fica em "Hora a confirmar"
  - [x] Nomear, juntar e separar momentos (só catálogo), preservados em recálculos
  - [x] Correção de relógio por dispositivo de captura ("+1 h", "ano errado"), com prévia, só no catálogo, reversível
  - [x] Momento como escopo na Comparar (entrada nova no JSON do escopo, `v: 2`) e como filtro
  - [x] Schema: tabelas novas para momentos, edições de momentos e correções por dispositivo (migração aditiva v3 → v4)
- [x] Miniaturas em cache (Shell API + fallback)
- [x] Biblioteca: grade, lista, linha do tempo, painel de detalhes
- [x] Filtros em chips + avançado, seleção em massa, filtros salvos — incluindo faixa de horário, período do dia, dia da semana, momento e confiança da hora
- [x] Critérios da spec (100 mil itens, < 1 s)
- [x] Teste do usuário (2026-10-29, celular simulado com `-DemoPersistente -CelularSimulado`): retomada da conferência depois de fechar OK, Biblioteca, momentos nomeados, filtros, seleção e painel de detalhes OK; correção de relógio funcionou, mas pouco intuitiva
- [x] Ajustes de usabilidade pedidos no teste (spec §3.1, §3.3 e §8.1)
  - [x] Situações de backup com nomes que dizem se tem backup: "Sem backup (só em 1 lugar)", "Parece ter cópia (falta conferir)", "Tem cópia conferida", "Backup em outro disco", "Ainda não dá para saber" (rótulos, contadores e dicas)
  - [x] Filtros "Horário do dia" e "Hora confiável?"; "Mostrar tudo, menos os marcados"; contagens com unidade ("3 fotos e vídeos")
  - [x] Momento de 1 instante mostra só "09:00"; momento sem nome ganha nome descritivo ("Sábado de manhã", "Sábado, da manhã à tarde"); botão "Opções" visível e menu pelo clique direito (ou toque longo) no cabeçalho
  - [x] Possível bug "1º de janeiro de 2023 · 00:00": a foto do demo tem mesmo essa data no EXIF (gerada de propósito). Como é a data de relógio zerado, a regra mudou: 1º de janeiro às 00:00:00 em ponto vira hora incerta e vai para "Hora a confirmar"; catálogos existentes são recalculados ao abrir (pelas datas já guardadas, sem reler arquivos), e o painel explica o motivo
  - [x] Dicas em ícones, selos, chips e botões (selo de backup diz onde o arquivo está: "Sem backup: este arquivo só existe em 'Pixel de Teste'"); botão "?" na navegação com a ajuda da tela aberta e a legenda das cores; guia de primeiros passos (4 passos) que pode ser pulado e reaberto pelo "?"
  - [x] Correção de relógio mais intuitiva: modo padrão "Sei a hora certa de uma foto" (escolhe a foto, vê a hora que ela marca, digita a hora certa) com a frase "O relógio estava adiantado 1 h: todas as fotos… vão ficar 1 h mais cedo"
  - [x] Testes: guia (passos, pular, não volta sozinho), "?" por tela e reabrir o guia (achou e corrigiu um erro ao reabrir o guia pelo "?"), nomes de momento, dica de backup com o lugar, regra do relógio zerado e recálculo ao abrir
- [x] Tag `v0.4.0` em 90cb75b (2026-10-29), CI run 40918675886 verde

Observações da Fase 4:
- Evidências: core — datas (15 testes: padrões de nome, EXIF com subsegundos/fuso, horário de verão antigo de SP, vídeo UTC, WhatsApp, conflito), ExifTool/ffprobe reais (arquivos intactos, nenhum arquivo novo), cenário completo com câmera + Europa (+02:00) + vídeo + WhatsApp + sem data + celular simulado lido pelo começo do arquivo (ordem real, momentos, editar/juntar/separar sobrevivendo a 3 recálculos, confirmar hora, correção de relógio com prévia/aplicar/desfazer e hash dos arquivos igual antes e depois, filtros, Comparar com momento); desempenho com 100 mil itens: 13 consultas entre 100 e 370 ms, momentos em ~1,4 s. App — linha do tempo intercalando dispositivos, hora a confirmar, filtro de período, seleção Ctrl/“todos”, nomear momento pelo cabeçalho, momento na Comparar, correção de relógio com ExifTool real. Helper — miniatura real pelo Shell (inclusive por caminho `\\?\Volume{GUID}`), recusas de escrita, `readHead`.
- Itens só aparecem na Biblioteca depois de conferidos (há aviso com a contagem). Vídeo de celular com o índice no fim fica com a data do nome ou do arquivo (lemos só o começo pelo USB).
- Miniaturas de HEIC/RAW dependem dos codecs do Windows (Shell); sem codec, ícone do tipo.
- A CLI ainda não tem comandos de Biblioteca/momentos (o core é testado direto); fica para quando a Fase 5 precisar dos testes por processo.
- O `.gitignore` ignorava `thumbnails/` (dados pessoais) e, no Windows, pegou a pasta de código `Thumbnails/` do helper: a CI quebrou em 2 runs até a exceção ser adicionada.
- Um teste de widget travou localmente (consulta em tempo real esperando uma gravação feita no relógio do teste); corrigido com prazo e nova tentativa. O processo do teste travado ficou preso segurando `app\build\native_assets\windows\sqlite3.dll` — os testes do app foram rodados numa cópia de trabalho separada (`.wt/`, ignorada).

## Fase 5 — Cópia segura (concluída em 2026-10-30)
- [x] Diário de operações e máquina de estados por item (`operation_items` + `operation_events` na mesma transação, commit antes de cada efeito no disco; tabelas já existiam desde a v1, sem migração)
- [x] Protocolo de cópia (temp no destino, flush, rehash, publicação sem sobrescrever): `.part` com `CREATE_NEW` em `.fotoatlas-tmp` na raiz do destino, SHA-256 da origem durante a leitura, data de modificação preservada, `FlushFileBuffers`, releitura do `.part`, `MoveFileExW` sem substituição, registro no catálogo já conferido (ADR 0016)
- [x] Recuperação idempotente na inicialização (decide olhando o disco; também antes de "Continuar")
- [x] Assistente "Copiar o que falta" (unidades e celular), checagem de espaço e FAT32
  - [x] "Copiar para B…" (Comparar) e "Copiar para…" (Biblioteca) abrem o assistente: destino (sugerido pelo lado B), pasta, organização (ano/mês, ano/dia, tipo/ano, estrutura original, tudo junto), nomes repetidos (sufixo ou perguntar) e prévia (quantidade, tamanho, já no destino, espaço livre, conflitos, FAT32 > 4 GB, nomes ajustados, hora incerta, pastas)
  - [x] Celular: `devices.pullToFile` no helper (grava o `.part`, SHA-256 na leitura, flush) + releitura no core; desconexão no meio pausa e retoma
  - [x] CLI: `copy plan|start|resume|retry|status|export` e `recover`
- [x] Testes de falha matando o processo em cada estado (11 pontos + morte no meio da própria recuperação; estado conferido no momento da morte; recuperação 3× sem efeito colateral; cópia termina sem perda nem sobrescrita) + falta de espaço, FAT32 > 4 GB (VHD), conflito de nome, origem que some, celular desconectado no meio
- [x] Tela Tarefas (fila + histórico + exportação): progresso, pausar/continuar/cancelar, decisão de conflito, tentar de novo, temporários desconhecidos (nunca apagados), relatório CSV
- [x] CI 3× seguidas verde depois das correções: runs 40964865635, 40966178709, 40967412559 (core com kill e VHD, app e helper)
- [x] Teste do usuário com dados de demonstração (2026-10-30): prévia, cópia com conferência, conflito virou `_1` sem tocar no original, Comparar deu "Sim, 100%" depois, assistente recusou copiar o que já estava no destino. Desconexão e fechar no meio: cobertos pelos testes automáticos (não testados à mão)
- [x] Ajustes de usabilidade pedidos no teste (2026-10-30)
  - [x] Comparar: abas "Em A, não contido em B — faltam" / "Em B, não contido em A" / "Contido em A e em B", com dica citando os nomes reais dos lados; dicas em todos os comandos; "Copiar para B…" desabilitado diz o que marcar
  - [x] Assistente: caminho completo do destino (quebra linha, com dica); quando tudo já está no destino, sugere outro destino e "Adicionar dispositivo…"
  - [x] Tarefas › Detalhes: copiados (origem → destino), salvos com outro nome com o porquê, não copiados com o motivo (core: `OperationItemView.renamedForConflict`)
- [x] Tag `v0.5.0` (2026-10-30)

Observações da Fase 5:
- Evidências: core — 14 testes do fluxo (prévia, protocolo completo com eventos em ordem, data preservada, comparação 100% depois, isolate, sufixo sem tocar no existente, "perguntar" com renomear/não copiar, idêntico fora do catálogo não duplica, espaço na prévia e no meio, FAT32 na prévia e no executor, pasta renomeada × unidade inteira saindo, celular desplugado no meio com IDs novos ao voltar, pausar/cancelar, temporário desconhecido intacto, reabrir 3× sem mudança); CLI com kill em 11 pontos + na recuperação (12 testes); helper real com celular simulado desplugando no meio (`pullToFile`); helper `dotnet test` (gravação, recusa fora de `.fotoatlas-tmp`, nunca sobrescreve, parcial na desconexão). App — assistente (destino/pasta de B, prévia, sem gravar antes de confirmar, sem espaço/FAT32 bloqueiam), Tarefas (pausar, continuar, conflito, cancelar, vazio) e cópia de verdade pela interface com o core real.
- Achado na CI (run 40955686652): no VHD de 64 MB o disco cheio de verdade não deu `ERROR_DISK_FULL` e o item virou "falhou"; agora uma falha de gravação com o disco realmente sem espaço (medido no disco) pausa por falta de espaço.
- Achado na CI (run 40957864584): um teste antigo da conferência falhou com "Erro de leitura (Win32 0)": o `GetLastError` lido via FFI às vezes vem zerado (já visto no `listDirectory`). Como a cópia decide pelo código de erro, toda abertura, leitura de atributos, criação de `.part`/pasta, publicação e remoção do próprio `.part` agora refaz a operação quando a falha vem com código 0 (`retryOnZeroError`; só operações que não mudam nada quando falham). Suíte do core 3× seguidas verde localmente.
- Achado na CI (run 40962539372): o teste de desempenho do scan mediu 205 ms de atraso (histórico: 15–16 ms). O próprio teste gerava os 50 mil arquivos no isolate medido e uma coleta de lixo grande caía no meio do scan; a geração foi para outro isolate (local: 14, 11, 14 ms; antes 12, 13, 52 ms).
- Os testes com VHD só rodam como administrador (CI); nesta máquina ficam pulados.
- O demo do celular ganhou um arquivo no HD com o mesmo nome de uma foto que falta (outra foto, renomeada), para mostrar o sufixo `_1`; a comparação Pixel × HD continua "faltam 3 · nos dois 3 · só em B 1".
- `{momento}` nos modelos e a prévia em árvore "antes → depois" ficam para a Fase 6 (reorganização).

## Fase 6 — Reorganização (implementada em 2026-10-30; aguarda o teste do usuário)
Cuidados pedidos pelo usuário (2026-10-30), registrados na spec §12 e no ADR 0017: pastas vazias nunca são apagadas automaticamente (só "Remover pastas vazias", pasta a pasta, com confirmação, só as realmente vazias); reorganizar só move no mesmo disco (outro disco = cópia conferida; celular nunca); Desfazer funciona depois de reabrir e não devolve sem perguntar arquivo que mudou. Decisões sem resposta do usuário, seguindo o plano aprovado: acompanhantes `.xmp`/`.aae`/`.thm` vão junto (opção no assistente, ligada por padrão) e "biblioteca principal" = configuração "disco principal" (destino sugerido nas cópias).
- [x] Modelos de estrutura e prévia em árvore antes → depois (2026-10-30)
  - [x] Assistente "Reorganizar…" no cartão do disco: pasta, modelo, pasta de "hora a confirmar", nomes repetidos, acompanhantes; prévia com frases e árvore "Antes (de onde saem)" → "Depois (para onde vão)", pastas novas, "fica vazia (não é apagada)", nomes ajustados destacados; "Copiar para outro disco…" abre a cópia conferida
- [x] Modelo com momento: `{ano}/{ano}-{mes}-{dia} {momento}/` (momento sem nome → início do momento; hora a confirmar → pasta própria; sanitização de nomes), variáveis de hora usando as correções do catálogo (spec §12) (2026-10-30)
  - [x] `{hora}`, `{minuto}`, `{segundo}`, `{momento}`; data do início do momento (momento que atravessa a meia-noite fica numa pasta); os mesmos modelos na cópia
- [x] Movimentação no mesmo volume via diário + Desfazer (2026-10-30)
  - [x] `MoveFileExW` sem substituir e sem copiar; catálogo atualizado na mesma transação; recuperação pelo disco; schema v5 aditivo (`expected_mtime`, `undo_of_item_id`)
  - [x] Desfazer pelo diário (após reabrir), prévia com mudados/sumidos/ocupados, decisões em Tarefas ("Devolver mesmo assim", "Mover com outro nome", "Deixar onde está")
  - [x] "Remover pastas vazias…" em Tarefas (lista cada pasta; ocultos impedem; confere de novo antes de remover); disco principal em Dispositivos
  - [x] CLI `reorg plan|start|resume|undo|resolve|folders|status`; `recover` inclui a reorganização
  - [x] Demonstração: `-DemoPersistente` gera a pasta "HD bagunçado"
- [x] Critérios da spec (2026-10-30): interrupção recuperável (kill em 3 pontos × reorganização e Desfazer + na recuperação, 3× sem efeito colateral); Desfazer restaura exatamente a estrutura anterior (arquivos e pastas, depois de reabrir o core); modelo com momento gera a árvore esperada (momento nomeado com caracteres inválidos, sem nome, atravessando a meia-noite, hora a confirmar)
- [ ] Teste do usuário (roteiro com o "HD bagunçado" da demonstração)
- [ ] Tag `v0.6.0`

Observações da Fase 6:
- Evidências: core — `reorg_test` (9 testes: modelos, árvore do critério, mover + catálogo + reescanear + reabrir + Desfazer exato + remover pastas criadas, Desfazer com arquivo mudado/sumido/lugar ocupado e decisões, origem mudada antes de mover, "perguntar", pastas vazias com Thumbs.db oculto, celular/desconectado/sem escaneamento bloqueiam); `reorg_demo_test` (cenário da demonstração com e sem ExifTool real); `reorg_kill_test` (8 testes com a CLI morta); migração v1–v4 → v5; teste de arquitetura (sem `COPY_ALLOWED`, `RemoveDirectoryW` só depois de conferir, reorganização sem API de exclusão). App — assistente (árvore, nada antes de confirmar, bloqueio, copiar para outro disco), celular sem botão, disco principal, Desfazer com avisos, decisões, pastas vazias; reorganizar e desfazer pela interface com o core real.
- Arquivos criados depois do último escaneamento não entram na reorganização (a prévia só usa o catálogo); escaneie antes.

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
- 2026-10-27 — Fase 3 — Celular só leitura: helper WPD (interop próprio sem métodos de escrita, GENERIC_READ, pendrives filtrados), celulares simulados, schema v3, cadastro pelo serial, scan por pasta com checkpoint e re-resolução de IDs, conferência pelo helper, celular × HD, app (Adicionar celular, avisos, "Manter originais"), CLI devices/add-phone. Evidências com o helper real e celular simulado; falta o teste do usuário (simulado e depois real, só leitura) e a tag v0.3.0.
- 2026-10-28 — Ajustes de interface antes da Fase 4 — "Adicionar dispositivo" único (celulares, unidades e "Escolher uma pasta…") em Dispositivos e na Comparar; "Escanear" com "Tudo" ou "Só algumas pastas" (árvore ao vivo, tamanho estimado, várias pastas num scan); cartão com as pastas já escaneadas. Spec §3.2/§7 atualizada. Fase 4 **não iniciada**: aguarda o usuário.
- 2026-10-29 — Correções do teste dos ajustes — app não fechava pelo X (close() de stream com ouvinte pausado + esperas sem prazo): encerramento com prazo e "Encerrando com segurança…" (ADR 0013); botão duplicado na Dispositivos vazia. Fase 4 **não iniciada**: aguarda o usuário.
- 2026-10-29 — Correções do fechamento com celular real — exceção solta `helper_crashed` (pedido órfão no HelperClient), pergunta antes de fechar com tarefas em andamento, aviso de queda do helper, conferência do celular gravada arquivo a arquivo (retoma exato). Fase 4 **não iniciada**: aguarda o usuário.
- 2026-10-29 — Ajustes do modo demonstração + Fase 4 — faixa "Modo demonstração" e textos ao fechar; run-app.ps1 -DemoPersistente. Fase 4: get-tools.ps1 (ExifTool/FFmpeg), datas da captura com fusos/origem/confiança, fila de metadados (celular pelo começo do arquivo), schema v4, momentos editáveis, correção de relógio com prévia, Biblioteca (linha do tempo, grade, lista, filtros E/OU/NÃO, filtros salvos, seleção, detalhes), miniaturas, Comparar com momento, 100 mil itens < 1 s. Tag v0.4.0 aguarda o teste do usuário.
- 2026-10-29 — Ajustes de usabilidade da Fase 4 (teste do usuário) — nomes das situações de backup, "Horário do dia"/"Hora confiável?", momentos com nome descritivo e menu pelo clique direito, dicas, botão "?" por tela, guia de primeiros passos, correção de relógio pela hora certa de uma foto, relógio zerado (1º/jan 00:00:00) como hora incerta. Tag v0.4.0. Fase 5 **não iniciada**: aguarda o usuário.
- 2026-10-29 — Fase 5 — Cópia segura: diário por item, protocolo completo (.part CREATE_NEW, flush, releitura, MoveFileExW sem substituir), recuperação idempotente pelo disco, assistente "Copiar para…" com prévia (Comparar e Biblioteca), tela Tarefas, celular como origem (`devices.pullToFile`), CLI copy/recover; kill em 11 pontos + na recuperação (3× sem efeito colateral), VHD FAT32 > 4 GB e disco cheio na CI. Achados da CI corrigidos (disco cheio sem ERROR_DISK_FULL; GetLastError zerado). Tag v0.5.0 aguarda o teste do usuário.
- 2026-10-30 — Ajustes de usabilidade da Fase 5 (teste do usuário) — abas da Comparar com "contém/contido" e dicas com os nomes dos lados, dicas nos comandos, caminho completo e próximo passo no assistente, Detalhes da tarefa com copiados/renomeados/não copiados. Tag v0.5.0. Fase 6 **não iniciada**: aguarda o usuário.
- 2026-10-30 — Retomada após o terminal fechar + Fase 6 — Conferido: tag v0.5.0 criada após CI verde; core da reorganização já pronto (commit). Fase 6 implementada: modelos com hora e momento, prévia em árvore, mover no mesmo disco com diário/recuperação, Desfazer pelo diário com aviso de arquivo mudado, remover pastas vazias só a pedido, disco principal, CLI reorg, demo "HD bagunçado", schema v5, ADR 0017. Tag v0.6.0 aguarda o teste do usuário.
