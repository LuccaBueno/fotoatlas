# Roda análise e testes de todo o monorepo (helper, fixtures, core, app).
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\test-all.ps1 [-SkipSlow]
param([switch]$SkipSlow)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')

function Step($name, $dir, [scriptblock]$block) {
    Write-Host "`n=== $name ===" -ForegroundColor Cyan
    Push-Location (Join-Path $root $dir)
    try {
        & $block
        if ($LASTEXITCODE -ne 0) { throw "$name falhou (código $LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
}

Step 'Helper: build' 'native\fotoatlas_helper' { dotnet build -warnaserror }
Step 'Helper: testes' 'native\fotoatlas_helper' { dotnet test --no-build }
Step 'Fixtures' 'tools\fixtures' { dart pub get; dart analyze --fatal-infos; dart test }
Step 'Core: análise' 'packages\fotoatlas_core' { dart pub get; dart analyze --fatal-infos }
if ($SkipSlow) {
    Step 'Core: testes (sem os lentos)' 'packages\fotoatlas_core' { dart test -x slow }
} else {
    Step 'Core: testes' 'packages\fotoatlas_core' { dart test }
}
Step 'App: análise e testes' 'app' { flutter pub get; flutter analyze --fatal-infos; flutter test }

Write-Host "`nTudo verde." -ForegroundColor Green
