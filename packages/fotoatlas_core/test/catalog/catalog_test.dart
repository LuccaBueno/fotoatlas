import 'dart:io';

import 'package:fotoatlas_core/src/catalog/catalog.dart';
import 'package:fotoatlas_core/src/catalog/catalog_database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

import '../support/temp.dart';

void main() {
  late Directory home;

  setUp(() async => home = await createTestTemp());

  test('cria o catálogo com os pragmas obrigatórios', () async {
    final catalog = await Catalog.open(p.join(home.path, 'catalog.db'));
    addTearDown(catalog.close);
    Future<Object?> pragma(String name) async =>
        (await catalog.db.customSelect('PRAGMA $name').getSingle()).data.values.first;

    expect(await pragma('journal_mode'), 'wal');
    expect(await pragma('synchronous'), 2, reason: '2 = FULL');
    expect(await pragma('foreign_keys'), 1);
    expect(await pragma('user_version'), CatalogDatabase.currentSchemaVersion);
  });

  test('cria todas as tabelas do schema v1', () async {
    final catalog = await Catalog.open(p.join(home.path, 'catalog.db'));
    addTearDown(catalog.close);
    final rows = await catalog.db.customSelect("SELECT name FROM sqlite_master WHERE type = 'table'").get();
    final names = rows.map((r) => r.read<String>('name')).toSet();
    expect(
      names,
      containsAll([
        'app_meta',
        'settings',
        'physical_disks',
        'sources',
        'scans',
        'scan_dirs',
        'scan_errors',
        'contents',
        'file_instances',
        'media_metadata',
        'date_corrections',
        'operations',
        'operation_items',
        'operation_events',
        'saved_filters',
        'selection_sets',
        'selection_set_items',
        'tags',
        'content_tags',
        'integrity_checks',
      ]),
    );
  });

  test('chave estrangeira é aplicada', () async {
    final catalog = await Catalog.open(p.join(home.path, 'catalog.db'));
    addTearDown(catalog.close);
    expect(
      () => catalog.db.customStatement(
        "INSERT INTO scans (source_id, kind, status, started_at) "
        "VALUES ('nao-existe', 'full', 'running', 0)",
      ),
      throwsA(anything),
    );
  });

  test('recusa catálogo de versão mais nova sem modificá-lo', () async {
    final path = p.join(home.path, 'catalog.db');
    final raw = sql.sqlite3.open(path)..execute('PRAGMA user_version = 99;');
    raw.close();
    final before = File(path).readAsBytesSync();

    await expectLater(Catalog.open(path), throwsA(isA<CatalogTooNewException>()));
    expect(File(path).readAsBytesSync(), before);
  });

  test('reabre um catálogo existente preservando os dados', () async {
    final path = p.join(home.path, 'catalog.db');
    var catalog = await Catalog.open(path);
    await catalog.db.customStatement("INSERT INTO app_meta (key, value) VALUES ('catalog_id', 'abc')");
    await catalog.close();

    catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final row = await catalog.db.customSelect("SELECT value FROM app_meta WHERE key = 'catalog_id'").getSingle();
    expect(row.read<String>('value'), 'abc');
  });

  test('close() só volta com o arquivo fechado: reabrir na hora funciona', () async {
    final path = p.join(home.path, 'catalog.db');
    for (var i = 0; i < 20; i++) {
      final catalog = await Catalog.open(path);
      await catalog.db.customStatement("INSERT INTO settings (key, value_json, updated_at) VALUES ('k$i', '1', 0)");
      await catalog.close();
      // A última conexão do SQLite em WAL apaga o -wal ao fechar: se ele ainda
      // existe, o arquivo continuava aberto (o shutdownAll() do drift responde
      // antes de o isolate fechar o banco).
      expect(File('$path-wal').existsSync(), isFalse, reason: 'rodada $i');
    }
    final raw = sql.sqlite3.open(path, mode: sql.OpenMode.readOnly);
    addTearDown(raw.close);
    expect(raw.select('SELECT COUNT(*) AS n FROM settings').first['n'], greaterThanOrEqualTo(20));
  });
}
