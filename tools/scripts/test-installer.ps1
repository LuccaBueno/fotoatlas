# Teste de instalação, atualização e desinstalação do FotoAtlas (ADR 0019).
# INSTALA DE VERDADE (pasta do programa, atalhos, registro do usuário) e abre o
# app, que cria o catálogo do usuário. Por isso só roda numa máquina de teste:
# na CI (GITHUB_ACTIONS) ou com -MaquinaDeTeste (ex.: dentro do Windows Sandbox).
# Recusa se já houver um FotoAtlas instalado ou um catálogo nesta conta.
#
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\test-installer.ps1 `
#        -InstaladorA dist\FotoAtlas-0.8.0-instalador.exe -InstaladorB dist\FotoAtlas-0.8.1-instalador.exe [-MaquinaDeTeste]
#
# Confere: arquivos, atalhos (menu Iniciar e área de trabalho), ícone do
# executável, ExifTool/FFmpeg/helper funcionando da pasta instalada, o app
# abrindo e usando o helper instalado; atualização recusada com o app aberto;
# atualização A → B sem mudar um byte do catálogo; desinstalação silenciosa que
# remove o programa e os atalhos e deixa o catálogo intacto.
param(
    [Parameter(Mandatory)][string]$InstaladorA,
    [Parameter(Mandatory)][string]$InstaladorB,
    [switch]$MaquinaDeTeste
)

$ErrorActionPreference = 'Stop'
if ($env:GITHUB_ACTIONS -ne 'true' -and -not $MaquinaDeTeste) {
    throw 'Este teste instala o FotoAtlas de verdade. Rode só na CI ou numa máquina de teste (-MaquinaDeTeste), nunca no seu computador de uso.'
}

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$InstaladorA = (Resolve-Path $InstaladorA).Path
$InstaladorB = (Resolve-Path $InstaladorB).Path
$versaoA = [regex]::Match((Split-Path $InstaladorA -Leaf), 'FotoAtlas-(\d+\.\d+\.\d+)-').Groups[1].Value
$versaoB = [regex]::Match((Split-Path $InstaladorB -Leaf), 'FotoAtlas-(\d+\.\d+\.\d+)-').Groups[1].Value

$appDir = Join-Path $env:LOCALAPPDATA 'Programs\FotoAtlas'
$catalogDir = Join-Path $env:APPDATA 'FotoAtlas'
$atalhoIniciar = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\FotoAtlas.lnk'
$atalhoDesktop = Join-Path ([Environment]::GetFolderPath('Desktop')) 'FotoAtlas.lnk'
$chave = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{6B0E5A52-3C4D-4F7B-9E21-8A1D2F0C7B3E}_is1'
$logs = Join-Path $root 'dist\teste-instalador'
New-Item -ItemType Directory -Force -Path $logs | Out-Null

foreach ($p in $appDir, $catalogDir, $chave) {
    if (Test-Path -LiteralPath $p) { throw "Recusado: $p já existe nesta conta (FotoAtlas instalado ou catálogo existente)." }
}

$falhas = 0
function Check([bool]$ok, [string]$texto) {
    if ($ok) { Write-Host "  ok   $texto" } else { Write-Host "  FALHOU  $texto" -ForegroundColor Red; $script:falhas++ }
}

function Install([string]$exe, [string]$nome) {
    $p = Start-Process -FilePath $exe -PassThru -Wait -ArgumentList @(
        '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/TASKS=desktopicon', "/LOG=`"$logs\$nome.log`"")
    return $p.ExitCode
}

function Snapshot {
    # Lista com SHA-256 de tudo na pasta do catálogo (catálogo, backups, configurações).
    Get-ChildItem -LiteralPath $catalogDir -Recurse -File | Sort-Object FullName | ForEach-Object {
        "$($_.FullName.Substring($catalogDir.Length))|$($_.Length)|$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
    } | Out-String
}

function Start-App {
    $p = Start-Process -FilePath (Join-Path $appDir 'fotoatlas.exe') -WorkingDirectory $appDir -PassThru
    $limite = (Get-Date).AddSeconds(90)
    while ((Get-Date) -lt $limite) {
        $p.Refresh()
        if ($p.HasExited) { throw "O app fechou sozinho ao abrir (código $($p.ExitCode))." }
        if ($p.MainWindowHandle -ne 0 -and (Test-Path -LiteralPath (Join-Path $catalogDir 'catalog.db'))) { break }
        Start-Sleep -Milliseconds 500
    }
    Start-Sleep -Seconds 5 # o app abre o catálogo e o helper
    return $p
}

function Stop-App($p) {
    [void]$p.CloseMainWindow()
    if (-not $p.WaitForExit(60000)) {
        Check $false 'o app fecha pelo X em até 60 s'
        $p.Kill(); $p.WaitForExit()
    }
    # O helper sai sozinho quando o app fecha (vigia do processo pai).
    $limite = (Get-Date).AddSeconds(20)
    while ((Get-Process fotoatlas_helper -ErrorAction SilentlyContinue) -and (Get-Date) -lt $limite) { Start-Sleep -Milliseconds 300 }
}

function Shortcut-Target([string]$lnk) { (New-Object -ComObject WScript.Shell).CreateShortcut($lnk).TargetPath }

Write-Host "== 1. Instalar $versaoA"
Check ((Install $InstaladorA 'instalar-A') -eq 0) 'instalador terminou sem erro'
foreach ($f in 'fotoatlas.exe', 'flutter_windows.dll', 'sqlite3.dll', 'data\app.so', 'fotoatlas_helper.exe',
    'tools\exiftool\exiftool.exe', 'tools\ffmpeg\ffprobe.exe', 'tools\ffmpeg\ffmpeg.exe', 'unins000.exe',
    'LICENSE.txt', 'AVISOS-DE-TERCEIROS.txt') {
    Check (Test-Path -LiteralPath (Join-Path $appDir $f)) "instalado: $f"
}
$exe = Join-Path $appDir 'fotoatlas.exe'
Check ((Shortcut-Target $atalhoIniciar) -eq $exe) 'atalho no menu Iniciar'
Check ((Shortcut-Target $atalhoDesktop) -eq $exe) 'atalho na área de trabalho'
Check ((Get-ItemProperty -LiteralPath $chave).DisplayVersion -eq $versaoA) "Aplicativos instalados mostra $versaoA"
Check ((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion -like "$versaoA*") "executável na versão $versaoA"
Check (-not (Test-Path -LiteralPath $catalogDir)) 'instalar não cria nem toca no catálogo'

# Ícone do executável = ícone gerado da logo (32 px, comparação pixel a pixel).
Add-Type -AssemblyName System.Drawing
$doExe = [System.Drawing.Icon]::ExtractAssociatedIcon($exe).ToBitmap()
$doIco = (New-Object System.Drawing.Icon (Join-Path $root 'app\windows\runner\resources\app_icon.ico'), 32, 32).ToBitmap()
$iguais = $doExe.Width -eq $doIco.Width
for ($y = 0; $iguais -and $y -lt $doIco.Height; $y += 3) {
    for ($x = 0; $x -lt $doIco.Width; $x += 3) { if ($doExe.GetPixel($x, $y) -ne $doIco.GetPixel($x, $y)) { $iguais = $false; break } }
}
Check $iguais 'executável com o ícone do FotoAtlas (globo com lupa)'

# Ferramentas de terceiros funcionando a partir da pasta instalada.
$ver = & (Join-Path $appDir 'tools\exiftool\exiftool.exe') -ver
Check ($ver -match '^\d+\.\d+') "ExifTool responde ($ver)"
$probe = & (Join-Path $appDir 'tools\ffmpeg\ffprobe.exe') -hide_banner -version | Select-Object -First 1
Check ($probe -match '^ffprobe version') 'ffprobe responde'
$hello = '' | & (Join-Path $appDir 'fotoatlas_helper.exe') | Select-Object -First 1
Check ($hello -match '"event":"hello"') 'helper responde (sem .NET instalado à parte)'

Write-Host '== 2. Abrir o app instalado'
$app = Start-App
Check (Test-Path -LiteralPath (Join-Path $catalogDir 'catalog.db')) "o app cria o catálogo em $catalogDir"
$helper = Get-CimInstance Win32_Process -Filter "Name = 'fotoatlas_helper.exe'" | Where-Object { $_.ParentProcessId -eq $app.Id }
Check ($helper -and $helper.ExecutablePath -eq (Join-Path $appDir 'fotoatlas_helper.exe')) 'o app usa o helper da pasta instalada'

Write-Host '== 3. Atualizar com o app aberto (tem de recusar)'
$codigo = Install $InstaladorB 'atualizar-com-app-aberto'
Check ($codigo -ne 0) "instalador recusou (código $codigo)"
Check ((Get-ItemProperty -LiteralPath $chave).DisplayVersion -eq $versaoA) "continua na versão $versaoA"
Stop-App $app

Set-Content -LiteralPath (Join-Path $catalogDir 'sentinela-do-teste.txt') -Value 'não pode sumir' -Encoding utf8
$antes = Snapshot
New-Item -ItemType File -Path (Join-Path $appDir 'tools\arquivo-da-versao-velha.txt') | Out-Null

Write-Host "== 4. Atualizar $versaoA → $versaoB"
Check ((Install $InstaladorB 'atualizar') -eq 0) 'atualização terminou sem erro'
Check ((Get-ItemProperty -LiteralPath $chave).DisplayVersion -eq $versaoB) "Aplicativos instalados mostra $versaoB"
Check (-not (Test-Path -LiteralPath (Join-Path $appDir 'tools\arquivo-da-versao-velha.txt'))) 'arquivos da versão velha saem da pasta do programa'
Check (Test-Path -LiteralPath (Join-Path $appDir 'tools\exiftool\exiftool.exe')) 'ExifTool continua instalado'
Check ((Shortcut-Target $atalhoIniciar) -eq $exe) 'atalho no menu Iniciar continua'
Check ((Shortcut-Target $atalhoDesktop) -eq $exe) 'atalho na área de trabalho continua'
Check ((Snapshot) -eq $antes) 'catálogo, backups e configurações idênticos byte a byte'

Write-Host '== 5. Abrir a versão nova com o catálogo da anterior'
$app = Start-App
Check (-not $app.HasExited) 'o app atualizado abre o catálogo existente'
Stop-App $app
$antes = Snapshot

Write-Host '== 6. Desinstalar (silencioso: a resposta padrão é manter o catálogo)'
$unins = Join-Path $appDir 'unins000.exe'
$p = Start-Process -FilePath $unins -PassThru -Wait -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$logs\desinstalar.log`""
Check ($p.ExitCode -eq 0) 'desinstalador terminou sem erro'
# O desinstalador continua numa cópia temporária: espera ele terminar.
$limite = (Get-Date).AddSeconds(90)
while ((Test-Path -LiteralPath $chave) -or (Test-Path -LiteralPath $exe)) {
    if ((Get-Date) -gt $limite) { break }
    Start-Sleep -Milliseconds 500
}
Start-Sleep -Seconds 2
Check (-not (Test-Path -LiteralPath $exe)) 'programa removido'
Check (-not (Test-Path -LiteralPath $chave)) 'sai de Aplicativos instalados'
Check (-not (Test-Path -LiteralPath $atalhoIniciar)) 'atalho do menu Iniciar removido'
Check (-not (Test-Path -LiteralPath $atalhoDesktop)) 'atalho da área de trabalho removido'
Check ((Snapshot) -eq $antes) 'catálogo, backups e configurações continuam idênticos'
Check (Test-Path -LiteralPath (Join-Path $catalogDir 'sentinela-do-teste.txt')) 'nada da pasta do catálogo foi apagado'

if ($falhas -gt 0) { throw "$falhas verificação(ões) falharam. Logs do instalador em $logs" }
Write-Host 'Instalação, atualização e desinstalação: tudo certo.' -ForegroundColor Green
# O Actions usa o $LASTEXITCODE do último programa chamado (ex.: o helper sai
# com código próprio quando a entrada acaba); o resultado do teste é este.
exit 0
