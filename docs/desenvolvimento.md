# Desenvolvimento — build, testes e execução

Requisitos: Windows 10/11, Flutter 3.47.7 stable, Visual Studio Build Tools 2022 (C++ desktop), .NET SDK 10, Git.

## Ferramentas de metadados (uma vez)

ExifTool 13.60 e FFmpeg 8.1 LGPL (ADR 0004 e 0005), com versão e SHA-256 fixados, baixados para `third_party\bin\` (não versionado). Sem eles o app funciona, mas as datas vêm só do nome e da data do arquivo, e vídeos ficam sem miniatura; os testes que precisam deles são pulados (na CI, falham).

```powershell
cd C:\dev\fotoatlas
powershell -ExecutionPolicy Bypass -File tools\scripts\get-tools.ps1
```

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

Os testes do core marcados `slow` (50 mil arquivos, CLI) podem ser pulados com `dart test -x slow`. Os de desempenho (`perf`: geram 50 mil arquivos e saturam o disco) rodam sozinhos na CI, depois dos outros: `dart test -x perf` e depois `dart test -t perf`.

## Rodar o app

```powershell
# Catálogo temporário de demonstração (não toca no catálogo real)
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 -Demo

# Catálogo temporário + celulares simulados (Pixel e iPhone) e uma pasta "HD" — sem celular real
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 -CelularSimulado

# Demonstração MANTIDA entre aberturas (sempre %TEMP%\fotoatlas_demo_persistente),
# para testar a retomada: fechar no meio do scan/conferência e abrir de novo.
# Com -CelularSimulado, o Pixel simulado lê devagar (3 s por arquivo).
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 -DemoPersistente -CelularSimulado

# Catálogo real em %APPDATA%\FotoAtlas
powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1
```

Com `-Demo` ou `-CelularSimulado`, o app mostra a faixa "Modo demonstração — tudo será descartado ao fechar" e as pastas temporárias (`%TEMP%\fotoatlas_demo_*`, `fotoatlas_celular_*`) são apagadas quando o app fecha (`-ManterDemo` guarda para inspeção, mas a próxima abertura começa do zero). Com `-DemoPersistente`, a faixa avisa que os dados são mantidos e a pasta só é apagada pelo `clean-temp.ps1` (com o app fechado). Para limpar sobras de testes interrompidos ou de demonstrações antigas — só pastas de `%TEMP%` que começam com `fotoatlas_`; as que estão em uso ficam intactas:

```powershell
powershell -ExecutionPolicy Bypass -File tools\scripts\clean-temp.ps1 -Simular   # só lista
powershell -ExecutionPolicy Bypass -File tools\scripts\clean-temp.ps1
```

Os testes apagam as próprias pastas temporárias e **falham** se alguma sobrar (sinal de catálogo ou processo que não foi fechado).

O app procura o helper em `FOTOATLAS_HELPER`, ao lado do executável ou na saída de build de `native\fotoatlas_helper`. Sem o helper, ele segue funcionando, mas sem informações de disco físico nem celulares.

Celulares simulados: `FOTOATLAS_FAKE_DEVICES=<pasta>` faz o helper mostrar os aparelhos descritos nos JSON dessa pasta (formato em `docs/protocolo-helper.md` §5.3.1). Gere uma com `dart run bin/gen_phone_demo.dart --out <pasta no temp>` em `tools/fixtures`.

## CLI

```powershell
cd C:\dev\fotoatlas\packages\fotoatlas_core
$env:FOTOATLAS_HOME = "$env:TEMP\fotoatlas_cli_demo"
dart run bin/fotoatlas_cli.dart volumes
dart run bin/fotoatlas_cli.dart sources add "C:\caminho\para\uma\pasta" --name Teste
dart run bin/fotoatlas_cli.dart scan start Teste
dart run bin/fotoatlas_cli.dart scan start Celular --folder "Armazenamento interno/DCIM/Camera"   # só uma pasta
dart run bin/fotoatlas_cli.dart scan start Celular --folder "Armazenamento interno/DCIM/Camera" --folder "Armazenamento interno/WhatsApp"   # várias pastas
dart run bin/fotoatlas_cli.dart sources list
dart run bin/fotoatlas_cli.dart hash run                     # confere o conteúdo (Ctrl+C pausa)
dart run bin/fotoatlas_cli.dart coverage                     # situação de backup
dart run bin/fotoatlas_cli.dart compare "Teste:pasta1+Teste:pasta2" "Outra:pasta3" --list missing
dart run bin/fotoatlas_cli.dart scopes save "Fotos do celular antigo" "Teste:pasta1+Teste:pasta2"
dart run bin/fotoatlas_cli.dart compare "@Fotos do celular antigo" "Outra" --type photo,video
dart run bin/fotoatlas_cli.dart backup now
```

Um lado da comparação é `FONTE[:pasta/sub]` com `+` entre as partes, ou `@NOME` de um escopo salvo. As linhas `VERDICT`, `MISSING`, `ONLY_B`, `BOTH`, `ISSUE` e `WARN` são estáveis para scripts e testes.

Depois de mudar `schema.drift` (nova versão do schema):

```powershell
cd C:\dev\fotoatlas\packages\fotoatlas_core
dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/src/catalog/catalog_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_schema/
dart format .
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
| `FOTOATLAS_EXIFTOOL`, `FOTOATLAS_FFPROBE`, `FOTOATLAS_FFMPEG` | Caminhos das ferramentas de metadados (senão: `tools\` ao lado do executável ou `third_party\bin\` do repositório) |
| `FOTOATLAS_REQUIRE_TOOLS` | `1` (CI): testes com ExifTool/ffprobe reais falham em vez de serem pulados se a ferramenta faltar |
| `FOTOATLAS_DEMO` | Definida pelo `run-app.ps1`: `descartavel` ou `persistente` (faixa "Modo demonstração") |

## Convenções

- Rode `build_runner` **antes** de `dart format .` (a CI confere que o código gerado e a formatação estão atualizados).
- Testes nunca usam pastas pessoais: tudo em `Directory.systemTemp.createTemp` ou em `tools/fixtures/out` (ignorado pelo git).
