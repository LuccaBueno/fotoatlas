# Compila o helper e abre o app em modo de desenvolvimento.
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 [-Demo] [-CelularSimulado] [-ManterDemo]
#   -Demo: usa um catálogo temporário (não toca no catálogo real em %APPDATA%).
#   -CelularSimulado: catálogo temporário + celulares simulados (Pixel e iPhone)
#     e uma pasta "HD" com parte das fotos, para testar a Fase 3 sem celular.
#     Nenhum celular real é lido nesse modo.
#   -ManterDemo: não apaga as pastas temporárias ao fechar o app.
# As pastas temporárias (%TEMP%\fotoatlas_*) são apagadas quando o app fecha.
param([switch]$Demo, [switch]$CelularSimulado, [switch]$ManterDemo)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$temporarias = @()

function Remove-Temporaria([string]$path) {
    # Só pastas do próprio script em %TEMP%. O helper sai sozinho quando o app
    # fecha (vigia do processo pai) e pode segurar arquivos por instantes.
    $temp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\') + '\'
    $full = [IO.Path]::GetFullPath($path)
    if (-not $full.StartsWith($temp, [StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path $full -Leaf).StartsWith('fotoatlas_')) {
        throw "Recusado: $full não é uma pasta temporária do FotoAtlas."
    }
    for ($i = 0; $i -lt 50 -and (Test-Path -LiteralPath $full); $i++) {
        try { Remove-Item -LiteralPath $full -Recurse -Force -ErrorAction Stop } catch { Start-Sleep -Milliseconds 200 }
    }
    if (Test-Path -LiteralPath $full) { Write-Warning "Não deu para apagar $full (ainda em uso). Rode tools\scripts\clean-temp.ps1 depois." }
}

Push-Location (Join-Path $root 'native\fotoatlas_helper')
try { dotnet build -nologo -v quiet; if ($LASTEXITCODE -ne 0) { throw 'build do helper falhou' } } finally { Pop-Location }

try {
    if ($Demo -or $CelularSimulado) {
        $env:FOTOATLAS_HOME = Join-Path $env:TEMP ('fotoatlas_demo_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $temporarias += $env:FOTOATLAS_HOME
        Write-Host "Catálogo de demonstração: $env:FOTOATLAS_HOME"
    }

    if ($CelularSimulado) {
        $out = Join-Path $env:TEMP ('fotoatlas_celular_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $temporarias += $out
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
} finally {
    Remove-Item Env:FOTOATLAS_HOME, Env:FOTOATLAS_FAKE_DEVICES -ErrorAction SilentlyContinue
    if ($ManterDemo) {
        if ($temporarias) { Write-Host "Mantidas: $($temporarias -join ', ')" }
    } else {
        foreach ($t in $temporarias) { Remove-Temporaria $t }
    }
}
