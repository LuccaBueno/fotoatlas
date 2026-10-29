# Apaga as pastas temporárias do FotoAtlas: só pastas de %TEMP% cujo nome começa
# com "fotoatlas_" (testes, demonstrações, builds da CLI). Nada fora de %TEMP%.
# Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\clean-temp.ps1 [-Simular]
#   -Simular: só lista o que seria apagado.
# Pasta em uso (app de demonstração aberto, teste rodando) fica intacta: antes de
# apagar, a pasta é renomeada, e o Windows recusa renomear pasta com arquivo aberto.
param([switch]$Simular)

$ErrorActionPreference = 'Stop'
$temp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$pastas = @(Get-ChildItem -LiteralPath $temp -Directory -Force | Where-Object { $_.Name.StartsWith('fotoatlas_', [StringComparison]::OrdinalIgnoreCase) })

if ($pastas.Count -eq 0) { Write-Host "Nenhuma pasta fotoatlas_* em $temp."; exit 0 }

$apagadas = 0; $emUso = 0
foreach ($p in $pastas) {
    # Conferência dupla: dentro de %TEMP% (sem subir por junction) e com o prefixo.
    if ($p.Parent.FullName.TrimEnd('\') -ne $temp -or ($p.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Write-Warning "Ignorada (fora de %TEMP% ou é um atalho de pasta): $($p.FullName)"
        continue
    }
    if ($Simular) { Write-Host "Apagaria: $($p.Name)"; continue }
    $alvo = Join-Path $temp ('fotoatlas_apagando_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    try {
        Rename-Item -LiteralPath $p.FullName -NewName (Split-Path $alvo -Leaf) -ErrorAction Stop
    } catch {
        Write-Host "Em uso, mantida: $($p.Name)"
        $emUso++
        continue
    }
    try { Remove-Item -LiteralPath $alvo -Recurse -Force -ErrorAction Stop } catch {
        # Caminhos com mais de 260 caracteres (fixtures): o rd com \\?\ apaga.
        cmd /c rd /s /q "\\?\$alvo" 2>$null
    }
    if (Test-Path -LiteralPath $alvo) {
        Write-Warning "Não deu para apagar tudo de $($p.Name) (sobrou em $alvo)."
    } else {
        $apagadas++
    }
}
if (-not $Simular) { Write-Host "Apagadas: $apagadas. Em uso: $emUso." }
