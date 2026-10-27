# Compila o helper e abre o app em modo de desenvolvimento.
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 [-Demo] [-CelularSimulado]
#   -Demo: usa um catálogo temporário (não toca no catálogo real em %APPDATA%).
#   -CelularSimulado: catálogo temporário + celulares simulados (Pixel e iPhone)
#     e uma pasta "HD" com parte das fotos, para testar a Fase 3 sem celular.
#     Nenhum celular real é lido nesse modo.
param([switch]$Demo, [switch]$CelularSimulado)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')

Push-Location (Join-Path $root 'native\fotoatlas_helper')
try { dotnet build -nologo -v quiet; if ($LASTEXITCODE -ne 0) { throw 'build do helper falhou' } } finally { Pop-Location }

if ($Demo -or $CelularSimulado) {
    $env:FOTOATLAS_HOME = Join-Path $env:TEMP ('fotoatlas_demo_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host "Catálogo de demonstração: $env:FOTOATLAS_HOME"
}

if ($CelularSimulado) {
    $out = Join-Path $env:TEMP ('fotoatlas_celular_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Push-Location (Join-Path $root 'tools\fixtures')
    try {
        dart pub get | Out-Null
        dart run bin/gen_phone_demo.dart --out $out
        if ($LASTEXITCODE -ne 0) { throw 'falha ao gerar os celulares simulados' }
    } finally { Pop-Location }
    $env:FOTOATLAS_FAKE_DEVICES = Join-Path $out 'celulares'
}

Push-Location (Join-Path $root 'app')
try { flutter run -d windows } finally { Pop-Location }
