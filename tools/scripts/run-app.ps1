# Compila o helper e abre o app em modo de desenvolvimento.
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 [-Demo]
#   -Demo: usa um catálogo temporário (não toca no catálogo real em %APPDATA%).
param([switch]$Demo)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')

Push-Location (Join-Path $root 'native\fotoatlas_helper')
try { dotnet build -nologo -v quiet; if ($LASTEXITCODE -ne 0) { throw 'build do helper falhou' } } finally { Pop-Location }

if ($Demo) {
    $env:FOTOATLAS_HOME = Join-Path $env:TEMP ('fotoatlas_demo_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    Write-Host "Catálogo de demonstração: $env:FOTOATLAS_HOME"
}

Push-Location (Join-Path $root 'app')
try { flutter run -d windows } finally { Pop-Location }
