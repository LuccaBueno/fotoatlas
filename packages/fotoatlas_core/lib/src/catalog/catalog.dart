import 'dart:io';
import 'dart:isolate';

import 'package:drift/isolate.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;

import 'catalog_database.dart';

/// O banco foi criado por uma versão mais nova do FotoAtlas.
class CatalogTooNewException implements Exception {
  CatalogTooNewException(this.found, this.supported);
  final int found;
  final int supported;

  @override
  String toString() =>
      'O catálogo é da versão $found, mas este FotoAtlas só conhece até a '
      'versão $supported. Atualize o FotoAtlas.';
}

/// Pragmas obrigatórios (spec §11.3), aplicados em toda conexão.
void applyPragmas(sql.Database db) {
  db.execute('PRAGMA journal_mode = WAL;');
  db.execute('PRAGMA synchronous = FULL;');
  db.execute('PRAGMA foreign_keys = ON;');
  db.execute('PRAGMA busy_timeout = 5000;');
  db.execute('PRAGMA temp_store = MEMORY;');
}

/// Catálogo aberto: um único escritor (o isolate do drift); outros isolates
/// se conectam por [connectPort].
class Catalog {
  Catalog._(this.db, this._isolate, this.path);

  final CatalogDatabase db;
  final DriftIsolate _isolate;
  final String path;

  /// Porta para workers abrirem sua própria conexão com o mesmo escritor.
  SendPort get connectPort => _isolate.connectPort;

  /// Abre (ou cria) o catálogo em [dbPath].
  ///
  /// Recusa bancos de versão mais nova e, antes de migrar um banco antigo,
  /// faz `VACUUM INTO` para `backups/pre-migracao-vN-<data>.db`.
  static Future<Catalog> open(String dbPath) async {
    Directory(p.dirname(dbPath)).createSync(recursive: true);
    _preflight(dbPath);
    final isolate = await DriftIsolate.spawn(() => NativeDatabase(File(dbPath), setup: applyPragmas));
    final db = CatalogDatabase(await isolate.connect(singleClientMode: false));
    // Força a abertura (e a criação/migração) agora, para que erros apareçam
    // aqui e não na primeira consulta da interface.
    await db.customSelect('SELECT 1').get();
    return Catalog._(db, isolate, dbPath);
  }

  /// Conexão de um worker ao escritor único do catálogo.
  static Future<CatalogDatabase> connectWorker(SendPort port) async {
    final isolate = DriftIsolate.fromConnectPort(port);
    return CatalogDatabase(await isolate.connect(singleClientMode: false));
  }

  static void _preflight(String dbPath) {
    if (!File(dbPath).existsSync()) return;
    // Só leitura: um banco que vamos recusar não pode ser modificado.
    final raw = sql.sqlite3.open(dbPath, mode: sql.OpenMode.readOnly);
    try {
      final version = raw.select('PRAGMA user_version;').first.values.first as int;
      const supported = CatalogDatabase.currentSchemaVersion;
      if (version > supported) {
        throw CatalogTooNewException(version, supported);
      }
      if (version > 0 && version < supported) {
        final backups = Directory(p.join(p.dirname(dbPath), 'backups'))..createSync(recursive: true);
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[^0-9]'), '').substring(0, 14);
        final target = p.join(backups.path, 'pre-migracao-v$version-$stamp.db');
        // VACUUM INTO falha se o arquivo já existir: nunca sobrescreve.
        raw.execute('VACUUM INTO ?;', [target]);
      }
    } finally {
      raw.close();
    }
  }

  Future<void> close() async {
    await db.close();
    await _isolate.shutdownAll();
  }
}
