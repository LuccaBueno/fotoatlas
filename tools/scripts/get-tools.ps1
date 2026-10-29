# Baixa o ExifTool e o FFmpeg (ffprobe/ffmpeg, build LGPL) para third_party\bin\
# (não versionado). Versões e SHA-256 fixados: se o arquivo baixado não bater,
# nada é instalado (ADR 0004 e 0005).
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\get-tools.ps1 [-Forcar]
#   -Forcar: baixa de novo mesmo se a versão certa já estiver instalada.
# Grava somente em third_party\bin\ do repositório e numa pasta de %TEMP%.
param([switch]$Forcar)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue' # o Invoke-WebRequest fica muito lento com a barra
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$destBase = Join-Path $root 'third_party\bin'

$ferramentas = @(
    @{
        Nome    = 'exiftool'
        Versao  = '13.60'
        # exiftool.org só mantém a versão mais nova; o SourceForge guarda todas.
        Urls    = @(
            'https://sourceforge.net/projects/exiftool/files/exiftool-13.60_64.zip/download',
            'https://exiftool.org/exiftool-13.60_64.zip'
        )
        Sha256  = '548b1f4e0b713cd2a26824b34080c35db4e2d2edd166468eb38b1d55ada90c2e'
        Instalar = {
            param($extraido, $destino)
            $pasta = Join-Path $extraido 'exiftool-13.60_64'
            Copy-Item -LiteralPath (Join-Path $pasta 'exiftool_files') -Destination $destino -Recurse
            # O executável vem como "exiftool(-k).exe" (o -k espera Enter ao sair).
            Copy-Item -LiteralPath (Join-Path $pasta 'exiftool(-k).exe') -Destination (Join-Path $destino 'exiftool.exe')
        }
    },
    @{
        Nome    = 'ffmpeg'
        Versao  = 'n8.1.3-9-g29e619e767-lgpl'
        # Build mensal do BtbN (os de fim de mês ficam guardados).
        Urls    = @('https://github.com/BtbN/FFmpeg-Builds/releases/download/autobuild-2026-09-30-13-08/ffmpeg-n8.1.3-9-g29e619e767-win64-lgpl-8.1.zip')
        Sha256  = '4a7642b2264c03e8a0ce8a3825b933ee5580656f45695a086fe7e294045ffc0a'
        Instalar = {
            param($extraido, $destino)
            $pasta = Get-ChildItem -LiteralPath $extraido -Directory | Select-Object -First 1
            foreach ($f in 'ffprobe.exe', 'ffmpeg.exe') {
                Copy-Item -LiteralPath (Join-Path $pasta.FullName "bin\$f") -Destination $destino
            }
            Copy-Item -LiteralPath (Join-Path $pasta.FullName 'LICENSE.txt') -Destination $destino
        }
    }
)

New-Item -ItemType Directory -Force -Path $destBase | Out-Null
foreach ($t in $ferramentas) {
    $destino = Join-Path $destBase $t.Nome
    $marca = Join-Path $destino 'VERSAO.txt'
    if (-not $Forcar -and (Test-Path -LiteralPath $marca) -and ((Get-Content -LiteralPath $marca -Raw).Trim() -eq $t.Versao)) {
        Write-Host "$($t.Nome) $($t.Versao) já instalado."
        continue
    }
    $tmp = Join-Path $env:TEMP ('fotoatlas_tools_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp 'download.zip'
        $ok = $false
        foreach ($url in $t.Urls) {
            Write-Host "Baixando $($t.Nome) $($t.Versao)…"
            try {
                Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing -UserAgent 'Wget' -MaximumRedirection 10
            } catch {
                Write-Warning "Falhou ($url): $_"
                continue
            }
            $sha = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($sha -eq $t.Sha256) { $ok = $true; break }
            Write-Warning "SHA-256 diferente do esperado ($sha) em $url"
        }
        if (-not $ok) { throw "Não deu para baixar $($t.Nome) $($t.Versao) com o SHA-256 esperado. Nada foi instalado." }
        $extraido = Join-Path $tmp 'x'
        Expand-Archive -LiteralPath $zip -DestinationPath $extraido
        # Instala numa pasta nova e só então troca: nunca fica meia instalação.
        $novo = "$destino.novo"
        if (Test-Path -LiteralPath $novo) { Remove-Item -LiteralPath $novo -Recurse -Force }
        New-Item -ItemType Directory -Path $novo | Out-Null
        & $t.Instalar $extraido $novo
        Set-Content -LiteralPath (Join-Path $novo 'VERSAO.txt') -Value $t.Versao -Encoding ascii
        if (Test-Path -LiteralPath $destino) { Remove-Item -LiteralPath $destino -Recurse -Force }
        Rename-Item -LiteralPath $novo -NewName (Split-Path $destino -Leaf)
        Write-Host "$($t.Nome) $($t.Versao) instalado em $destino"
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
