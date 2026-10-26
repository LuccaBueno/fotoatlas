# 0001 — Flutter para a interface e core em Dart puro com CLI

- Status: aceita
- Data: 2026-10-26

## Contexto
É preciso um app desktop Windows responsivo, com regras críticas de segurança de dados testáveis sem interface, inclusive matando o processo no meio de uma cópia (spec §4, §17).

## Alternativas consideradas
- **WinUI 3 / WPF (C#)**: nativo, mas a lógica ficaria acoplada à UI e a spec já decidiu por Flutter.
- **Electron/Tauri**: bom ecossistema web, mas usa mais memória e o acesso a Win32 é menos direto.
- **Flutter com a lógica dentro do app**: mais simples no começo, mas impede testes de falha por CLI.

## Decisão
- `app/`: Flutter (Windows), só com apresentação e estado de tela.
- `packages/fotoatlas_core/`: Dart puro (sem `package:flutter`), com toda a regra de negócio, I/O e banco.
- `fotoatlas_cli` (em `bin/` do core): usa a mesma fachada; serve para testes de integração/falha e para diagnóstico.

## Consequências
- Licenças: Flutter/Dart BSD-3.
- O core é testado com `dart test` e o app com `flutter test`.
- A CI precisa de Windows (FFI Win32); o Dart vem junto com o Flutter.
- Risco: a fronteira app↔core precisa ficar fina; a revisão de código barra lógica de negócio dentro de `app/`.
