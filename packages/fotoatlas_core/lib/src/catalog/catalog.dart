import 'dart:async';
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
  Catalog._(this.db, this._isolate, this.path, this._exited);

  final CatalogDatabase db;
  final DriftIsolate _isolate;

  /// Completa quando o isolate do drift termina, o que só acontece depois de
  /// ele fechar o arquivo do SQLite.
  final Future<void> _exited;
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
    final exit = ReceivePort();
    final exited = exit.first.then((_) => exit.close());
    final isolate = await DriftIsolate.spawn(
      _opener(dbPath),
      isolateSpawn: <T>(entry, message) => Isolate.spawn<T>(entry, message, onExit: exit.sendPort),
    );
    final db = CatalogDatabase(await isolate.connect(singleClientMode: false));
    // Força a abertura (e a criação/migração) agora, para que erros apareçam
    // aqui e não na primeira consulta da interface.
    await db.customSelect('SELECT 1').get();
    return Catalog._(db, isolate, dbPath, exited);
  }

  /// Fora de [open] para o closure (enviado ao isolate) não levar junto a
  /// porta de saída, que não pode ser enviada.
  static NativeDatabase Function() _opener(String dbPath) =>
      () => NativeDatabase(File(dbPath), setup: applyPragmas);

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

  /// Fecha e só volta quando o arquivo foi fechado de verdade: o
  /// `shutdownAll()` do drift responde antes de o isolate fechar o SQLite, e
  /// reabrir logo em seguida (no mesmo processo) dava "database is locked".
  ///
  /// O `db.close()` do drift espera os streams de consultas reativas
  /// (`watch()`) fecharem; com um ouvinte pausado (o Riverpod pausa as telas
  /// fora de vista) isso nunca termina. Por isso não esperamos por ele: quem
  /// fecha o arquivo é o isolate do banco, no `shutdownAll()`.
  Future<void> close() async {
    unawaited(db.close().then((_) {}, onError: (Object _) {}));
    await _isolate.shutdownAll();
    await _exited;
  }
}
