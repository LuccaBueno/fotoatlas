# Registros de Decisão de Arquitetura (ADRs)

Um arquivo por decisão: `NNNN-titulo-curto.md`.

Modelo:

```markdown
# NNNN — Título

- Status: proposta | aceita | substituída por NNNN
- Data: AAAA-MM-DD

## Contexto
## Alternativas consideradas
## Decisão
## Consequências (licença, manutenção, riscos)
```

## Índice

| ADR | Título | Status |
|---|---|---|
| [0001](0001-flutter-e-core-dart-puro.md) | Flutter para a interface e core em Dart puro com CLI | aceita |
| [0002](0002-sqlite-drift.md) | SQLite via `sqlite3` + `drift` | aceita |
| [0003](0003-helper-csharp-dotnet10.md) | Helper nativo em C# .NET 10, processo separado com JSON-lines | aceita |
| [0004](0004-exiftool.md) | ExifTool para metadados de foto | aceita |
| [0005](0005-ffmpeg-lgpl.md) | FFprobe/FFmpeg em build LGPL | aceita |
| [0006](0006-riverpod.md) | Riverpod para o estado da interface | aceita |
| [0007](0007-testes-de-falha.md) | Estratégia de testes, incluindo testes de falha (kill) | aceita |
| [0008](0008-win32-via-ffi-no-core.md) | Acesso Win32 no core via FFI, com bindings próprios mínimos | aceita |
| [0009](0009-identificacao-de-fontes.md) | Identificação de fontes por pontuação | aceita |
| [0010](0010-fila-de-hash.md) | Fila de conferência de conteúdo (SHA-256) e `package:crypto` | aceita |
| [0011](0011-comparacao-por-escopo.md) | Comparação A × B com escopo livre | aceita |
| [0012](0012-celular-wpd-somente-leitura.md) | Celular pelo WPD, somente leitura (interop próprio, celulares simulados) | aceita |
| [0013](0013-encerramento-com-prazo.md) | Encerramento com prazo: fechar o app sempre funciona (helper finalizado se travar) | aceita |
