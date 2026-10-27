import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import '../safe_io/move_no_replace.dart';
import 'catalog_database.dart';

/// Um backup do catálogo em disco.
class CatalogBackupInfo {
  const CatalogBackupInfo(this.path, this.createdAt, this.sizeBytes);
  final String path;
  final DateTime createdAt;
  final int sizeBytes;
}

/// Falha ao fazer backup (o catálogo e os backups anteriores ficam intactos).
class CatalogBackupException implements Exception {
  CatalogBackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Backup automático do catálogo (`VACUUM INTO`) com rotação
/// (`docs/arquitetura.md` §3.2).
///
/// 1. `PRAGMA quick_check` no catálogo: se falhar, não faz backup e não roda
///    a rotação — um catálogo com defeito nunca empurra os bons para fora.
/// 2. `VACUUM INTO backups/catalog-<data>.db.tmp`.
/// 3. Abre a cópia só para leitura e confere `quick_check` e a versão.
/// 4. Publica com `MoveFileExW` sem sobrescrever → `catalog-<data>.db`.
/// 5. Rotação: mantém os [keep] mais novos `catalog-*.db`. Os
///    `pre-migracao-*` nunca são apagados.
///
/// Só mexe em arquivos do próprio FotoAtlas na pasta `backups/` (regra 8).
class CatalogBackupService {
  CatalogBackupService(this.db, this.catalogPath, {this.keep = 10});

  final CatalogDatabase db;
  final String catalogPath;
  final int keep;

  String get backupsDir => p.join(p.dirname(catalogPath), 'backups');

  static final _name = RegExp(r'^catalog-(\d{8})-(\d{6})(?:-(\d+))?\.db$');

  /// Backups existentes, do mais novo para o mais antigo.
  List<CatalogBackupInfo> list() {
    final dir = Directory(backupsDir);
    if (!dir.existsSync()) return const [];
    final out = <CatalogBackupInfo>[];
    for (final f in dir.listSync().whereType<File>()) {
      final m = _name.firstMatch(p.basename(f.path));
      if (m == null) continue;
      final d = m.group(1)!, t = m.group(2)!;
      final at = DateTime.utc(
        int.parse(d.substring(0, 4)),
        int.parse(d.substring(4, 6)),
        int.parse(d.substring(6, 8)),
        int.parse(t.substring(0, 2)),
        int.parse(t.substring(2, 4)),
        int.parse(t.substring(4, 6)),
      );
      out.add(CatalogBackupInfo(f.path, at, f.lengthSync()));
    }
    out.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : p.basename(b.path).compareTo(p.basename(a.path));
    });
    return out;
  }

  CatalogBackupInfo? get latest {
    final all = list();
    return all.isEmpty ? null : all.first;
  }

  /// Faz backup se o último tiver mais de [every] (ou não houver nenhum).
  Future<CatalogBackupInfo?> maybeBackup({Duration every = const Duration(hours: 24), DateTime? now}) async {
    final last = latest;
    final t = now ?? DateTime.now().toUtc();
    if (last != null && t.difference(last.createdAt) < every) return null;
    return backupNow(now: t);
  }

  Future<CatalogBackupInfo> backupNow({DateTime? now}) async {
    final check = await db.customSelect('PRAGMA quick_check').get();
    final result = check.map((r) => r.data.values.first.toString()).join('; ');
    if (result != 'ok') {
      throw CatalogBackupException(
        'O catálogo tem problemas ($result). O backup não foi feito; os anteriores foram mantidos.',
      );
    }
    Directory(backupsDir).createSync(recursive: true);
    final t = (now ?? DateTime.now()).toUtc();
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp = '${t.year}${two(t.month)}${two(t.day)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
    var finalPath = p.join(backupsDir, 'catalog-$stamp.db');
    for (var i = 2; File(finalPath).existsSync() || File('$finalPath.tmp').existsSync(); i++) {
      finalPath = p.join(backupsDir, 'catalog-$stamp-$i.db');
    }
    final tmp = '$finalPath.tmp';
    // VACUUM INTO falha se o arquivo existir: nunca sobrescreve.
    await db.customStatement('VACUUM INTO ?', [tmp]);
    final version = CatalogDatabase.currentSchemaVersion;
    final problem = await Isolate.run(() => _verify(tmp, version));
    if (problem != null) {
      throw CatalogBackupException(
        'A cópia do catálogo não passou na conferência ($problem). Os backups anteriores foram mantidos.',
      );
    }
    moveNoReplace(tmp, finalPath);
    _rotate();
    return CatalogBackupInfo(finalPath, t, File(finalPath).lengthSync());
  }

  static String? _verify(String path, int version) {
    final raw = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
    try {
      final ok = raw.select('PRAGMA quick_check').map((r) => r.values.first.toString()).join('; ');
      if (ok != 'ok') return ok;
      final v = raw.select('PRAGMA user_version').first.values.first as int;
      if (v != version) return 'versão $v, esperada $version';
      return null;
    } finally {
      raw.close();
    }
  }

  void _rotate() {
    final all = list();
    for (final old in all.skip(keep)) {
      try {
        File(old.path).deleteSync();
      } on FileSystemException {
        // Fica para a próxima rotação.
      }
    }
    // Sobras de um backup interrompido (nunca publicadas).
    for (final f in Directory(backupsDir).listSync().whereType<File>()) {
      final name = p.basename(f.path);
      if (!name.startsWith('catalog-') || !name.endsWith('.db.tmp')) continue;
      if (DateTime.now().difference(f.lastModifiedSync()) < const Duration(hours: 1)) continue;
      try {
        f.deleteSync();
      } on FileSystemException {
        // Idem.
      }
    }
  }
}
