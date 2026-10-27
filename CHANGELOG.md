# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado] — Fase 2: Conteúdo e cobertura (tag `v0.2.0` depois do teste do usuário)

### Requisitos ajustados (sem implementação ainda)
- **Data e hora da captura (até segundos) como cidadã de primeira classe** — spec §3.2, §8.1–8.3, §10, §12 e §16; ROADMAP das Fases 4 e 6: linha do tempo única intercalando todos os dispositivos pela hora real; **momentos** automáticos (intervalo sem fotos, padrão 2 h) que o usuário pode nomear, juntar e separar, usados como filtro, escopo na Comparar e no modelo de organização `{ano}/{ano}-{mes}-{dia} {momento}/`; filtros por faixa de horário, período do dia e dia da semana; correção de relógio por dispositivo de captura com prévia, só no catálogo; hora de baixa confiança sinalizada e fora dos momentos automáticos até ser confirmada.

### Adicionado
- **Conferência de conteúdo (SHA-256)** em segundo plano, um leitor por disco físico, em isolates (ADR 0010). Lê os arquivos só para leitura, sem baixar placeholders do OneDrive, e detecta arquivo que mudou depois do escaneamento ou durante a leitura (tamanho e data antes e depois). Erro de leitura fica registrado com o motivo e nunca vira "ausente". Pausar/continuar; "tentar de novo" para os que falharam; começa sozinha depois de cada escaneamento e quando um dispositivo conecta. Retomada exata depois de o processo ser morto.
- **Duplicatas exatas e cobertura de backup**: 🔴 só 1 cópia, 🟡 provável cópia (falta conferir), 🟢 cópia conferida no mesmo disco, 🔵 backup em disco independente, ⚪ desconhecido. O mesmo arquivo visto por duas fontes sobrepostas conta uma vez; disco de identidade incerta nunca conta como independente; dispositivo desconectado continua contando. Espaço ocupado por arquivos repetidos, por dispositivo.
- **Comparar com escopo livre** (ADR 0011): A e B com uma ou mais pastas e/ou dispositivos inteiros, filtro por tipo e **escopos salvos com nome**. Resposta direta a "B contém todo o conteúdo de A?" — "Sim, 100%", "Faltam N arquivos (X GB)" com a lista pronta para seleção, ou "Resultado incompleto" quando há arquivo sem conteúdo conferido, pasta não lida ou dispositivo nunca escaneado. Também "Só em B" e "Nos dois". Sempre por conteúdo; nomes e pastas não importam. "Conferir agora" prioriza os arquivos dos dois escopos.
- **Backup automático do catálogo** (`VACUUM INTO`): conferido antes de publicar, nunca sobrescreve, guarda os 10 mais novos e preserva os backups de migração. Automático uma vez por dia ao abrir o app e manual em Configurações.
- **App**: Início com o painel "O que já tem backup e o que ainda não tem" e o progresso da conferência; Dispositivos com a situação de backup e os repetidos de cada fonte; tela **Comparar** completa; **Configurações** com o backup do catálogo.
- **CLI**: `hash run|retry`, `coverage`, `compare A B [--list] [--type]`, `scopes list|save|remove`, `backup now|list`.
- **Schema v2** (aditivo): `file_instances.hash_error` e tabela `saved_scopes`, com teste de migração a partir do snapshot da v1.

### Corrigido
- O `ProviderScope` do app ficava dentro do `MaterialApp`, e diálogos não enxergavam os providers (o seletor de pastas da comparação quebraria). Achado pelo teste do app com o core real.

### Segurança
- Leitura de arquivos de usuário só por `safe_io/source_reader.dart` (`GENERIC_READ`, `OPEN_EXISTING`, `FILE_FLAG_OPEN_NO_RECALL`); o teste de arquitetura confere as flags e agora também pega os nomes Dart dos bindings (`createFile`, `moveFileEx`).
- Publicação sem sobrescrever (`MoveFileExW` sem `REPLACE_EXISTING`) já usada no backup do catálogo.

### Evidências (critérios da Fase 2)
- Conteúdo idêntico com nomes diferentes é agrupado; mesmo nome com conteúdo diferente não é (testes do core).
- "Só 1 cópia" correto num cenário de 3 fontes (2 no mesmo disco, 1 em outro), inclusive com disco de identidade fraca e fontes sobrepostas.
- Arquivo que cresce ou é reescrito com o mesmo tamanho durante a leitura é detectado.
- Comparação A = pasta1 + pasta2 × B = pasta3, com nomes diferentes e conteúdo parcial: faltam 2 (2.400 bytes), só em B 1, nos dois 2; "incompleto" com hash pendente em qualquer lado (core, CLI, app com core real).
- 100 mil arquivos no catálogo: cobertura ~1,5 s, comparação ~0,2 s, página da lista ~0,2 s (fora da thread da interface).
- Kill no meio da conferência → retomar termina sem duplicar conteúdo; nova execução não faz nada.

### Alterado
- **Requisito da comparação ajustado** (spec §3.2, §9 e §16): A e B passam a ser escopos livres (várias pastas e/ou dispositivos, com filtros), a pergunta principal é "B contém todo o conteúdo de A?" (sempre por conteúdo), com resultado "incompleto" quando há arquivos sem conteúdo conferido, e escopos podem ser salvos com nome.
- CI: `actions/checkout@v7` e `actions/setup-dotnet@v6` (Node 24); `subosito/flutter-action@v2` já usa `actions/cache@v5` (Node 24). Disparo manual (`workflow_dispatch`) para repetir a CI.

### Testes
- VHD: a conferência pelo Windows (`Get-DiskImage`) mostrou que, depois do `detach vdisk` do diskpart, o disco continuava anexado — a tolerância a "already detached" escondia isso. Agora o teste desanexa com `Dismount-DiskImage` e confere o estado, sem tolerância (3 execuções seguidas verdes na CI).

## [0.1.0] — 2026-10-26 — Fase 1: Fundação

### Adicionado
- **Catálogo SQLite v1** (drift): todas as tabelas de `docs/schema-v1.md`, com WAL, `synchronous=FULL` e `foreign_keys`. Recusa abrir um catálogo de versão mais nova, faz backup antes de migrar, usa um único escritor em isolate e permite só um processo por vez (`catalog.lock`).
- **Helper nativo** (C# .NET 10): protocolo JSON-lines v1 (`hello`, `system.*`, cancelamento, vigia do processo pai) e `volumes.list`, que traz GUID, serial, sistema de arquivos, espaço e disco físico, com uma classificação de identidade conservadora para seriais falsos de gavetas USB e de NVMe. Regras de escrita prontas para as próximas fases.
- **Cliente do helper** com reinício automático (espera crescente), ping de vigilância e reserva Win32 quando o helper não está disponível.
- **Cadastro de fontes** (pastas e unidades inteiras), reconhecido por pontuação (ADR 0009) e independente da letra da unidade. Casos ambíguos pedem confirmação, a conectividade é verificada a cada 3 s e há aviso de pastas sobrepostas. Fonte desconectada continua visível com os dados do último scan.
- **Escaneamento de listagem** (sem hash) com `FindFirstFileExW` e caminhos `\\?\`, em isolate próprio, com checkpoint transacional por lote: pausar, retomar e cancelar, scan incremental e retomada após o processo morrer. Uma ausência só é confirmada em scan completo; pasta com erro de leitura nunca vira exclusão. Junctions e symlinks não são seguidos. Placeholders do OneDrive são catalogados sem serem abertos. Lixeira, `System Volume Information`, `.fotoatlas-tmp` e pastas do sistema ficam de fora.
- **CLI** `fotoatlas_cli`: `volumes`, `sources add|list`, `scan start|resume|status`, e crashpoints para testes de falha.
- **Gerador de fixtures sintéticos** determinístico (`tools/fixtures`): nomes de celular/câmera/WhatsApp, Unicode, nomes repetidos, cópias idênticas e caminho com mais de 260 caracteres.
- **App Windows**: navegação lateral com as 6 telas, tema claro/escuro e textos em PT-BR. Telas **Início** (visão geral, alertas, atalhos) e **Dispositivos** (adicionar pasta/unidade, escanear, pausar, retomar, cancelar, renomear, esquecer, confirmar unidade). As demais telas explicam o que virá.
- **CI** no GitHub Actions (windows-latest): helper, core + fixtures e app (análise, formatação, código gerado, testes e build).
- Documentação: `docs/desenvolvimento.md`, atualizações dos ADRs 0007, 0008 e 0009; snapshot do schema (`drift_schemas/drift_schema_v1.json`).

### Segurança
- Teste de arquitetura impede que módulos não autorizados gravem, movam ou apaguem arquivos.
- `GetLastError` via FFI às vezes vem zerado (medido: ~1 em 2.000). A listagem só termina com `ERROR_NO_MORE_FILES` e, em qualquer outro caso, refaz a pasta ou registra erro, nunca uma "lista mais curta".

### Evidências (critérios da Fase 1)
- 50 mil arquivos em 294 pastas escaneados em ~1,6 s; atraso máximo do event loop principal de 10–15 ms durante o scan.
- Troca de letra reconhecida (volumes simulados e VHD real NTFS e FAT32 na CI).
- Fonte desconectada visível com os dados do último scan (testes do core e do app).
- Processo morto no meio do scan (TerminateProcess) → retomada com contagem exata, sem duplicatas.

## Etapa 0 — Planejamento
- Especificação técnica v4.1, roteiro, CLAUDE.md e conceito de logo.
- Análise da especificação, arquitetura, schema SQLite v1, protocolo do helper nativo, ADRs 0001–0009 e plano da Fase 1.
