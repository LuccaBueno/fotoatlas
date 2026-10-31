# Confere os documentos .md do repositório:
# - salvos em UTF-8 com BOM (o Get-Content do Windows PowerShell 5.1 troca os
#   acentos de arquivos sem BOM);
# - sem caminhos no formato do cmd (%TEMP%, %APPDATA%) nem estilo Linux
#   (/c/dev/...): as instruções usam PowerShell e caminhos completos.
#   A especificação (docs/FOTOATLAS_SPEC.md) fica de fora da segunda regra.
# Só lê. Uso: powershell -ExecutionPolicy Bypass -File tools\scripts\check-docs.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$problemas = @()
foreach ($rel in (git -C $root ls-files '*.md')) {
    $path = Join-Path $root $rel
    $bytes = [IO.File]::ReadAllBytes($path)
    if (-not ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)) {
        $problemas += "${rel}: sem BOM (salve como UTF-8 com BOM)"
    }
    if ($rel -eq 'docs/FOTOATLAS_SPEC.md') { continue }
    $texto = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    foreach ($proibido in @('%TEMP%', '%APPDATA%', '%LOCALAPPDATA%', '/c/dev', '/c/Users')) {
        if ($texto.Contains($proibido)) { $problemas += "${rel}: contém '$proibido' (use o caminho completo do Windows)" }
    }
}
if ($problemas.Count -gt 0) {
    $problemas | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    exit 1
}
Write-Host 'Documentos .md: todos com BOM e caminhos no formato do Windows.'
