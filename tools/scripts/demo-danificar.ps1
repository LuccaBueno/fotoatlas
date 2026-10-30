# Simula, na demonstração da Fase 7, um arquivo que se estragou no disco: troca
# alguns bytes no meio da foto e devolve a data de modificação original (como
# um setor danificado). Com -Editar, simula uma edição de verdade (bytes e data
# mudam), que o FotoAtlas deve classificar como "alterado", não "corrompido".
#
# Só mexe em arquivos de %TEMP%\fotoatlas_demo_persistente\Integridade (gerada
# por run-app.ps1 -DemoPersistente). Qualquer outro caminho é recusado.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tools\scripts\demo-danificar.ps1
#   powershell -ExecutionPolicy Bypass -File tools\scripts\demo-danificar.ps1 -Arquivo 'HD fotos\2024\IMG_0005.jpg' -Editar
param([string]$Arquivo = 'HD fotos\2024\IMG_0003.jpg', [switch]$Editar)

$ErrorActionPreference = 'Stop'
$base = [IO.Path]::GetFullPath((Join-Path $env:TEMP 'fotoatlas_demo_persistente\Integridade')).TrimEnd('\') + '\'
if (-not (Test-Path -LiteralPath $base)) {
    throw "A demonstração ainda não existe ($base). Abra uma vez com tools\scripts\run-app.ps1 -DemoPersistente."
}
$alvo = [IO.Path]::GetFullPath((Join-Path $base $Arquivo))
if (-not $alvo.StartsWith($base, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Recusado: $alvo não está dentro da pasta da demonstração ($base)."
}
$item = Get-Item -LiteralPath $alvo -Force
if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Recusado: $alvo é um atalho." }

$data = $item.LastWriteTimeUtc
$bytes = [IO.File]::ReadAllBytes($alvo)
$meio = [int]($bytes.Length / 2)
for ($i = 0; $i -lt 16 -and $meio + $i -lt $bytes.Length; $i++) { $bytes[$meio + $i] = $bytes[$meio + $i] -bxor 0xFF }
[IO.File]::WriteAllBytes($alvo, $bytes)

if ($Editar) {
    (Get-Item -LiteralPath $alvo).LastWriteTimeUtc = [DateTime]::UtcNow
    Write-Host "Editado (conteúdo e data mudaram): $alvo"
    Write-Host 'Esperado na verificação: "Alterado (foi editado...)", não "possivelmente corrompido".'
} else {
    (Get-Item -LiteralPath $alvo).LastWriteTimeUtc = $data
    Write-Host "Danificado (16 bytes trocados, data preservada: $($data.ToLocalTime())): $alvo"
    Write-Host 'Esperado na verificação: "Possivelmente corrompido", com a cópia do "HD cópia" para restaurar.'
}
