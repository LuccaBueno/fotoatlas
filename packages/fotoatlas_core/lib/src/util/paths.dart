import 'dart:io';

import 'package:path/path.dart' as p;

/// Pastas de dados (`docs/arquitetura.md` §3.2).
class CorePaths {
  const CorePaths({required this.dataDir, required this.localDir});

  /// `FOTOATLAS_HOME` substitui as duas raízes (CLI e testes).
  factory CorePaths.fromEnvironment([Map<String, String>? env]) {
    final e = env ?? Platform.environment;
    final home = e['FOTOATLAS_HOME'];
    if (home != null && home.isNotEmpty) {
      return CorePaths(dataDir: home, localDir: p.join(home, 'local'));
    }
    final appData = e['APPDATA'];
    final localAppData = e['LOCALAPPDATA'];
    if (appData == null || localAppData == null) {
      throw StateError('APPDATA/LOCALAPPDATA não definidos; defina FOTOATLAS_HOME.');
    }
    return CorePaths(dataDir: p.join(appData, 'FotoAtlas'), localDir: p.join(localAppData, 'FotoAtlas'));
  }

  /// Catálogo e backups (`%APPDATA%\FotoAtlas`).
  final String dataDir;

  /// Cache, miniaturas e logs (`%LOCALAPPDATA%\FotoAtlas`).
  final String localDir;

  String get catalogPath => p.join(dataDir, 'catalog.db');
  String get lockPath => p.join(dataDir, 'catalog.lock');
  String get thumbsDir => p.join(localDir, 'thumbs');
  String get logsDir => p.join(localDir, 'logs');
}
