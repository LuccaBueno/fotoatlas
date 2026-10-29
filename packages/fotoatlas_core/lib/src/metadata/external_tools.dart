import 'dart:io';

import 'package:path/path.dart' as p;

/// Executáveis de terceiros usados só para ler (ADR 0004 e 0005): ExifTool,
/// ffprobe e ffmpeg. Qualquer um pode faltar; o core segue com o que tiver.
class ExternalTools {
  const ExternalTools({this.exiftool, this.ffprobe, this.ffmpeg});

  final String? exiftool;
  final String? ffprobe;
  final String? ffmpeg;

  static const none = ExternalTools();

  /// Procura em `FOTOATLAS_EXIFTOOL`/`FOTOATLAS_FFPROBE`/`FOTOATLAS_FFMPEG`,
  /// ao lado do executável (`tools\…`, instalador) ou em `third_party\bin\…`
  /// subindo a partir de [startDir] (desenvolvimento, `get-tools.ps1`).
  static ExternalTools locate({String? startDir, Map<String, String>? environment}) {
    final env = environment ?? Platform.environment;
    String? find(String envName, String folder, String exe) {
      final fromEnv = env[envName];
      if (fromEnv != null && fromEnv.isNotEmpty) return File(fromEnv).existsSync() ? fromEnv : null;
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final beside = p.join(exeDir, 'tools', folder, exe);
      if (File(beside).existsSync()) return beside;
      var dir = Directory(startDir ?? Directory.current.path).absolute;
      for (var i = 0; i < 8; i++) {
        final candidate = p.join(dir.path, 'third_party', 'bin', folder, exe);
        if (File(candidate).existsSync()) return candidate;
        final parent = dir.parent;
        if (parent.path == dir.path) break;
        dir = parent;
      }
      return null;
    }

    return ExternalTools(
      exiftool: find('FOTOATLAS_EXIFTOOL', 'exiftool', 'exiftool.exe'),
      ffprobe: find('FOTOATLAS_FFPROBE', 'ffmpeg', 'ffprobe.exe'),
      ffmpeg: find('FOTOATLAS_FFMPEG', 'ffmpeg', 'ffmpeg.exe'),
    );
  }
}
