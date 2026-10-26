# Changelog

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e [Versionamento Semântico](https://semver.org/lang/pt-BR/).

## [Não lançado]

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
