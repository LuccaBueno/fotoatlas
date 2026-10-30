# Compila o helper e abre o app em modo de desenvolvimento.
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\run-app.ps1 [-Demo] [-CelularSimulado] [-ManterDemo] [-DemoPersistente]
#   -Demo: usa um catálogo temporário (não toca no catálogo real em %APPDATA%).
#     Tudo é descartado ao fechar; o app mostra uma faixa avisando.
#   -CelularSimulado: catálogo temporário + celulares simulados (Pixel e iPhone)
#     e uma pasta "HD" com parte das fotos, para testar a Fase 3 sem celular.
#     Nenhum celular real é lido nesse modo.
#   -ManterDemo: não apaga as pastas temporárias ao fechar o app (para inspecionar;
#     a próxima abertura usa outra pasta, então nada continua de onde parou).
#   -DemoPersistente: usa sempre a mesma pasta, %TEMP%\fotoatlas_demo_persistente,
#     e não a apaga ao fechar: serve para testar a retomada de verdade (fechar no
#     meio de um scan ou conferência e abrir de novo). Combina com -CelularSimulado
#     (os celulares simulados e o "HD" são gerados uma vez, na mesma pasta; o Pixel
#     lê devagar, 3 s por arquivo, para dar tempo de fechar no meio da conferência).
#     Para começar do zero: tools\scripts\clean-temp.ps1 (com o app fechado).
#     Também gera, uma vez, a pasta "HD bagunçado" (fotos sintéticas espalhadas)
#     para testar "Reorganizar…" (Fase 6).
# As pastas temporárias (%TEMP%\fotoatlas_*) de -Demo/-CelularSimulado são
# apagadas quando o app fecha.
param([switch]$Demo, [switch]$CelularSimulado, [switch]$ManterDemo, [switch]$DemoPersistente)

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

function New-CelularSimulado([string]$out, [switch]$Silencioso, [int]$LeituraLentaMs = 0) {
    Push-Location (Join-Path $root 'tools\fixtures')
    try {
        dart pub get | Out-Null
        $genArgs = @('run', 'bin/gen_phone_demo.dart', '--out', $out)
        if ($LeituraLentaMs -gt 0) { $genArgs += @('--leitura-lenta', $LeituraLentaMs) }
        if ($Silencioso) { dart @genArgs | Out-Null } else { dart @genArgs }
        if ($LASTEXITCODE -ne 0) { throw 'falha ao gerar os celulares simulados' }
    } finally { Pop-Location }
}

if ($DemoPersistente -and ($Demo -or $ManterDemo)) {
    throw '-DemoPersistente já é uma demonstração mantida: não combine com -Demo nem -ManterDemo.'
}

Push-Location (Join-Path $root 'native\fotoatlas_helper')
try { dotnet build -nologo -v quiet; if ($LASTEXITCODE -ne 0) { throw 'build do helper falhou' } } finally { Pop-Location }

try {
    if ($DemoPersistente) {
        $pasta = Join-Path $env:TEMP 'fotoatlas_demo_persistente'
        $env:FOTOATLAS_HOME = Join-Path $pasta 'catalogo'
        $env:FOTOATLAS_DEMO = 'persistente'
        Write-Host "Demonstração mantida entre aberturas: $pasta"
        Write-Host 'Para começar do zero, feche o app e rode tools\scripts\clean-temp.ps1.'
        # Fase 6: HD bagunçado sintético para testar "Reorganizar…" (gerado uma vez).
        $baguncado = Join-Path $pasta 'HD bagunçado'
        if (-not (Test-Path -LiteralPath $baguncado)) {
            $gerando = Join-Path $pasta 'hd_baguncado_gerando'
            if (Test-Path -LiteralPath $gerando) { Remove-Item -LiteralPath $gerando -Recurse -Force }
            Push-Location (Join-Path $root 'tools\fixtures')
            try {
                dart pub get | Out-Null
                dart run bin/gen_reorg_demo.dart --out $gerando | Out-Null
                if ($LASTEXITCODE -ne 0) { throw 'falha ao gerar o HD bagunçado' }
            } finally { Pop-Location }
            Rename-Item -LiteralPath $gerando -NewName 'HD bagunçado'
        }
        Write-Host "HD bagunçado para reorganizar (cadastre como pasta): $baguncado"
        if ($CelularSimulado) {
            $celular = Join-Path $pasta 'celular'
            if (-not (Test-Path -LiteralPath $celular)) {
                # Gera ao lado e só então renomeia: geração interrompida não
                # deixa uma pasta pela metade que seria reaproveitada depois.
                $gerando = Join-Path $pasta 'celular_gerando'
                if (Test-Path -LiteralPath $gerando) { Remove-Item -LiteralPath $gerando -Recurse -Force }
                New-CelularSimulado $gerando -Silencioso -LeituraLentaMs 3000
                Rename-Item -LiteralPath $gerando -NewName 'celular'
            } else {
                Write-Host "Celulares simulados já gerados: $celular"
            }
            $env:FOTOATLAS_FAKE_DEVICES = Join-Path $celular 'celulares'
            Write-Host "HD de backup (cadastre como pasta): $(Join-Path $celular 'HD')"
            Write-Host "Câmera com o relógio 1 h adiantado (cadastre como pasta): $(Join-Path $celular 'Câmera')"
            Write-Host 'Esperado (Pixel × HD): faltam 3 · nos dois 3 · só em B 1'
            Write-Host 'O Pixel simulado lê devagar (3 s por arquivo): dá tempo de fechar no meio da conferência ou da cópia.'
            Write-Host "Desplugar o Pixel no meio da cópia: renomeie $(Join-Path $celular 'celulares\pixel.json') para pixel.json.off"
        }
    } elseif ($Demo -or $CelularSimulado) {
        $env:FOTOATLAS_HOME = Join-Path $env:TEMP ('fotoatlas_demo_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $env:FOTOATLAS_DEMO = 'descartavel'
        $temporarias += $env:FOTOATLAS_HOME
        Write-Host "Catálogo de demonstração: $env:FOTOATLAS_HOME"
        if ($CelularSimulado) {
            $out = Join-Path $env:TEMP ('fotoatlas_celular_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
            $temporarias += $out
            New-CelularSimulado $out
            $env:FOTOATLAS_FAKE_DEVICES = Join-Path $out 'celulares'
        }
    }

    Push-Location (Join-Path $root 'app')
    try { flutter run -d windows } finally { Pop-Location }
} finally {
    Remove-Item Env:FOTOATLAS_HOME, Env:FOTOATLAS_FAKE_DEVICES, Env:FOTOATLAS_DEMO -ErrorAction SilentlyContinue
    if ($ManterDemo) {
        if ($temporarias) { Write-Host "Mantidas: $($temporarias -join ', ')" }
    } else {
        foreach ($t in $temporarias) { Remove-Temporaria $t }
    }
}
