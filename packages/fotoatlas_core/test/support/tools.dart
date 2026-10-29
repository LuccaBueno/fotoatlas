import 'dart:io';

/// Testes com ExifTool/ffprobe/ffmpeg reais: pulados se a ferramenta não foi
/// baixada (`tools\scripts\get-tools.ps1`), exceto com
/// `FOTOATLAS_REQUIRE_TOOLS=1` (CI), em que a falta é erro.
Object skipWithoutTool(String? path, String name) {
  if (path != null) return false;
  const script = r'tools\scripts\get-tools.ps1';
  if (Platform.environment['FOTOATLAS_REQUIRE_TOOLS'] == '1') {
    throw StateError('$name não encontrado e FOTOATLAS_REQUIRE_TOOLS=1. Rode $script.');
  }
  return '$name não encontrado: rode $script';
}
