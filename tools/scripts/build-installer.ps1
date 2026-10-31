# Gera o instalador do FotoAtlas para Windows (Inno Setup; ADR 0019).
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\build-installer.ps1 [-Versao 1.0.0] [-SoInstalador]
#   -Versao: versão do app e do instalador (padrão: a do app\pubspec.yaml).
#   -SoInstalador: não compila de novo; reaproveita dist\pacote (para gerar
#     outra versão do instalador com os mesmos arquivos, no teste de atualização).
# Resultado: dist\FotoAtlas-<versão>-instalador.exe.
# Grava somente em dist\ e nas pastas de build do repositório (e o get-tools.ps1
# numa pasta temporária). Precisa do Inno Setup 6 (https://jrsoftware.org/isdl.php).
param([string]$Versao, [switch]$SoInstalador)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$dist = Join-Path $root 'dist'
$pacote = Join-Path $dist 'pacote'

if (-not $Versao) {
    $linha = Select-String -LiteralPath (Join-Path $root 'app\pubspec.yaml') -Pattern '^version:\s*([0-9.]+)' | Select-Object -First 1
    $Versao = $linha.Matches[0].Groups[1].Value
}
if ($Versao -notmatch '^\d+\.\d+\.\d+$') { throw "Versão inválida: '$Versao' (use 1.2.3)." }

function Find-Iscc {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @("$env:LOCALAPPDATA\Programs", ${env:ProgramFiles(x86)}, $env:ProgramFiles)) {
        if (-not $base) { continue }
        $c = Join-Path $base 'Inno Setup 6\ISCC.exe'
        if (Test-Path -LiteralPath $c) { return $c }
    }
    throw 'Inno Setup 6 não encontrado. Instale de https://jrsoftware.org/isdl.php (ou: winget install JRSoftware.InnoSetup).'
}
$iscc = Find-Iscc

function Invoke-Checked([string]$what, [scriptblock]$block) {
    & $block
    if ($LASTEXITCODE -ne 0) { throw "$what falhou (código $LASTEXITCODE)." }
}

if (-not $SoInstalador) {
    Write-Host "== FotoAtlas ${Versao}: ExifTool e FFmpeg"
    & (Join-Path $PSScriptRoot 'get-tools.ps1')

    Write-Host '== Helper (.NET, autocontido: não precisa do .NET instalado)'
    $helperOut = Join-Path $dist 'helper'
    if (Test-Path -LiteralPath $helperOut) { Remove-Item -LiteralPath $helperOut -Recurse -Force }
    Invoke-Checked 'dotnet publish do helper' {
        dotnet publish (Join-Path $root 'native\fotoatlas_helper\FotoAtlas.Helper\FotoAtlas.Helper.csproj') `
            -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:PublishTrimmed=true `
            -p:DebugType=none -p:Version=$Versao -o $helperOut -nologo
    }

    Write-Host '== App (Flutter, release)'
    Push-Location (Join-Path $root 'app')
    try {
        Invoke-Checked 'flutter pub get' { flutter pub get }
        Invoke-Checked 'flutter build windows' {
            flutter build windows --release --build-name=$Versao --build-number=0 "--dart-define=FOTOATLAS_VERSION=$Versao"
        }
    } finally { Pop-Location }

    Write-Host "== Montando $pacote"
    if (Test-Path -LiteralPath $pacote) { Remove-Item -LiteralPath $pacote -Recurse -Force }
    New-Item -ItemType Directory -Path $pacote | Out-Null
    Copy-Item -Path (Join-Path $root 'app\build\windows\x64\runner\Release\*') -Destination $pacote -Recurse
    Copy-Item -LiteralPath (Join-Path $helperOut 'fotoatlas_helper.exe') -Destination $pacote
    $tools = New-Item -ItemType Directory -Path (Join-Path $pacote 'tools')
    foreach ($t in 'exiftool', 'ffmpeg') {
        Copy-Item -LiteralPath (Join-Path $root "third_party\bin\$t") -Destination (Join-Path $tools.FullName $t) -Recurse
    }
    Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $pacote 'LICENSE.txt')
    Copy-Item -LiteralPath (Join-Path $root 'installer\AVISOS-DE-TERCEIROS.txt') -Destination $pacote
}

# Confere o pacote antes de gerar o instalador: faltando qualquer peça, para.
$obrigatorios = @(
    'fotoatlas.exe', 'flutter_windows.dll', 'sqlite3.dll', 'data\app.so', 'data\icudtl.dat',
    'fotoatlas_helper.exe', 'tools\exiftool\exiftool.exe', 'tools\exiftool\exiftool_files\perl.exe',
    'tools\ffmpeg\ffprobe.exe', 'tools\ffmpeg\ffmpeg.exe', 'tools\ffmpeg\LICENSE.txt',
    'LICENSE.txt', 'AVISOS-DE-TERCEIROS.txt'
)
foreach ($f in $obrigatorios) {
    if (-not (Test-Path -LiteralPath (Join-Path $pacote $f))) { throw "Pacote incompleto: falta $f em $pacote" }
}
# Nada pessoal no pacote (repositório e instalador públicos).
$proibidos = Get-ChildItem -LiteralPath $pacote -Recurse -File |
    Where-Object { $_.Extension -in '.db', '.db-wal', '.db-shm', '.log', '.pdb' }
if ($proibidos) { throw "O pacote tem arquivos que não podem ir no instalador: $($proibidos.FullName -join ', ')" }

Write-Host "== Instalador (Inno Setup: $iscc)"
Invoke-Checked 'ISCC' {
    & $iscc /Q "/DAppVersion=$Versao" "/DSourceDir=$pacote" "/DOutputDir=$dist" (Join-Path $root 'installer\fotoatlas.iss')
}
$exe = Join-Path $dist "FotoAtlas-$Versao-instalador.exe"
$sha = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash.ToLowerInvariant()
$mb = [math]::Round((Get-Item -LiteralPath $exe).Length / 1MB, 1)
Write-Host "Pronto: $exe ($mb MB)"
Write-Host "SHA-256: $sha"
