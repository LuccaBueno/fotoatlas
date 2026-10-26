# Desenvolvimento — build, testes e execução

Requisitos: Windows 10/11, Flutter 3.47.7 stable, Visual Studio Build Tools 2022 (C++ desktop), .NET SDK 10, Git.

## Tudo de uma vez

```powershell
cd C:\dev\fotoatlas
powershell -ExecutionPolicy Bypass -File tools\scripts\test-all.ps1            # completo (inclui 50 mil arquivos, ~2 min)
powershell -ExecutionPolicy Bypass -File tools\scripts\test-all.ps1 -SkipSlow  # rápido
```

## Por parte

```powershell
# Helper nativo (C#)
cd C:\dev\fotoatlas\native\fotoatlas_helper; dotnet build -warnaserror; dotnet test

# Core (Dart puro) — gere o código do drift depois de mexer em schema.drift
cd C:\dev\fotoatlas\packages\fotoatlas_core; dart pub get; dart analyze; dart test
dart run build_runner build --delete-conflicting-outputs; dart format .

# Fixtures sintéticos
cd C:\dev\fotoatlas\tools\fixtures; dart pub get; dart test

# App
cd C:\dev\fotoatlas\app; flutter pub get; flutter analyze; flutter test
```

Os testes do core marcados `slow` (50 mil arquivos) podem ser pulados com `dart test -x slow`.

## Rodar o app

```powershell
# Catálogo temporário de demonstração (não toca no catálogo real)
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 -Demo

# Catálogo real em %APPDATA%\FotoAtlas
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1
```

O app procura o helper em `FOTOATLAS_HELPER`, ao lado do executável ou na saída de build de `native\fotoatlas_helper`. Sem o helper, ele segue funcionando, mas sem informações de disco físico.

## CLI

```powershell
cd C:\dev\fotoatlas\packages\fotoatlas_core
$env:FOTOATLAS_HOME = "$env:TEMP\fotoatlas_cli_demo"
dart run bin/fotoatlas_cli.dart volumes
dart run bin/fotoatlas_cli.dart sources add "C:\caminho\para\uma\pasta" --name Teste
dart run bin/fotoatlas_cli.dart scan start Teste
dart run bin/fotoatlas_cli.dart sources list
```

Para gerar uma árvore sintética e escanear:

```powershell
cd C:\dev\fotoatlas\tools\fixtures
dart run bin/gen_tree.dart --out "$env:TEMP\fotoatlas_arvore" --files 50000
```

## Variáveis de ambiente

| Variável | Efeito |
|---|---|
| `FOTOATLAS_HOME` | Pasta do catálogo, backups, cache e logs (substitui `%APPDATA%`/`%LOCALAPPDATA%`) |
| `FOTOATLAS_HELPER` | Caminho do `fotoatlas_helper.exe` |
| `FOTOATLAS_CRASHPOINT` | Só para testes de falha: `nome[:n]` bloqueia na n-ésima passagem pelo ponto (ADR 0007) |

## Convenções

- Rode `build_runner` **antes** de `dart format .` (a CI confere que o código gerado e a formatação estão atualizados).
- Testes nunca usam pastas pessoais: tudo em `Directory.systemTemp.createTemp` ou em `tools/fixtures/out` (ignorado pelo git).
