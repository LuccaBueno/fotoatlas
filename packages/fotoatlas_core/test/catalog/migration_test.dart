import 'dart:io';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:fotoatlas_core/src/catalog/catalog.dart';
import 'package:fotoatlas_core/src/catalog/catalog_database.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../generated_schema/schema.dart';
import '../support/temp.dart';

/// Migrações a partir dos *snapshots* versionados em `drift_schemas/`.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());

  test('v1 a v10 → v11: schema final igual ao de um catálogo novo', () async {
    for (final from in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
      final schema = await verifier.schemaAt(from);
      final db = CatalogDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 11);
      await db.close();
    }
  });

  test('v1 → v11 pelo Catalog.open: backup antes, dados preservados, colunas novas', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(1);
    schema.rawDatabase
      ..execute(
        "INSERT INTO sources (id, name, kind, root_rel_path, connected, created_at, updated_at) "
        "VALUES ('s1', 'HD antigo', 'external_hd', '', 0, 1, 1)",
      )
      ..execute(
        "INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes) "
        "VALUES ('s1', 'Fotos/a.jpg', 'Fotos', 'a.jpg', 'jpg', 10)",
      )
      ..execute('PRAGMA user_version = 1')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final db = catalog.db;
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 11);
    final row = await db.customSelect('SELECT name, hash_error, device_object_id FROM file_instances').getSingle();
    expect(row.read<String>('name'), 'a.jpg');
    expect(row.readNullable<String>('hash_error'), isNull);
    expect(row.readNullable<String>('device_object_id'), isNull);
    final source = await db.customSelect('SELECT device_serial, device_platform FROM sources').getSingle();
    expect(source.readNullable<String>('device_serial'), isNull);
    expect(await db.select(db.savedScopes).get(), isEmpty);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v1-')), hasLength(1));
  });

  test('v3 → v5: metadados antigos ficam, colunas novas vazias, momentos e correções vazios', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(3);
    schema.rawDatabase
      ..execute(
        "INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) VALUES (1, zeroblob(32), 10, 'photo', 1)",
      )
      ..execute(
        "INSERT INTO media_metadata (content_id, capture_utc_ms, date_source, date_confidence, make) "
        "VALUES (1, 1000, 'exif_original', 'medium', 'Canon')",
      )
      ..execute('PRAGMA user_version = 3')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final db = catalog.db;
    final row = await db
        .customSelect('SELECT make, capture_utc_ms, meta_status, eff_utc_ms, moment_id FROM media_metadata')
        .getSingle();
    expect(row.read<String>('make'), 'Canon');
    expect(row.read<int>('capture_utc_ms'), 1000);
    expect(row.read<String>('meta_status'), 'full');
    expect(row.readNullable<int>('eff_utc_ms'), isNull);
    expect(row.readNullable<int>('moment_id'), isNull);
    expect(await db.select(db.moments).get(), isEmpty);
    expect(await db.select(db.clockCorrections).get(), isEmpty);
    expect(await db.select(db.momentEdits).get(), isEmpty);
  });

  test('v4 → v5: cópias antigas ficam no histórico, colunas novas vazias', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase
      ..execute(
        "INSERT INTO sources (id, name, kind, root_rel_path, connected, created_at, updated_at) "
        "VALUES ('s1', 'HD', 'external_hd', '', 0, 1, 1)",
      )
      ..execute(
        "INSERT INTO operations (id, kind, status, dest_source_id, created_at) VALUES ('op', 'copy', 'completed', 's1', 1)",
      )
      ..execute(
        'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, expected_size, dst_source_id, '
        "dst_rel_path_planned, state, updated_at) VALUES ('op', 1, 's1', 'a.jpg', 10, 's1', 'b/a.jpg', 'published', 1)",
      )
      ..execute('PRAGMA user_version = 4')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final row = await catalog.db
        .customSelect('SELECT state, dst_rel_path_planned, expected_mtime, undo_of_item_id FROM operation_items')
        .getSingle();
    expect(row.read<String>('state'), 'published');
    expect(row.read<String>('dst_rel_path_planned'), 'b/a.jpg');
    expect(row.readNullable<int>('expected_mtime'), isNull);
    expect(row.readNullable<int>('undo_of_item_id'), isNull);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v4-')), hasLength(1));
  });

  test('v5 → v6: verificações antigas ficam, rodadas vazias, colunas novas vazias', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase
      ..execute(
        "INSERT INTO sources (id, name, kind, root_rel_path, connected, created_at, updated_at) "
        "VALUES ('s1', 'HD', 'external_hd', '', 0, 1, 1)",
      )
      ..execute(
        "INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, integrity) "
        "VALUES ('s1', 'a.jpg', '', 'a.jpg', 'jpg', 10, 'ok')",
      )
      ..execute("INSERT INTO integrity_checks (instance_id, checked_at, result) VALUES (1, 5, 'unchanged')")
      ..execute('PRAGMA user_version = 5')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final row = await catalog.db
        .customSelect('SELECT result, run_id, expected_content_id, reason FROM integrity_checks')
        .getSingle();
    expect(row.read<String>('result'), 'unchanged');
    expect(row.readNullable<int>('run_id'), isNull);
    expect(row.readNullable<int>('expected_content_id'), isNull);
    expect(row.readNullable<String>('reason'), isNull);
    expect(await catalog.db.select(catalog.db.integrityRuns).get(), isEmpty);
    expect(await catalog.db.select(catalog.db.integrityRunItems).get(), isEmpty);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v5-')), hasLength(1));
  });

  test('v6 → v7: corrompidos antigos continuam pendentes (resolvido vazio)', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(6);
    schema.rawDatabase
      ..execute(
        "INSERT INTO sources (id, name, kind, root_rel_path, connected, created_at, updated_at) "
        "VALUES ('s1', 'HD', 'external_hd', '', 0, 1, 1)",
      )
      ..execute(
        "INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, hash_status, integrity) "
        "VALUES ('s1', 'a.jpg', '', 'a.jpg', 'jpg', 10, 'error', 'possibly_corrupt')",
      )
      ..execute('PRAGMA user_version = 6')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final row = await catalog.db
        .customSelect('SELECT integrity, integrity_resolved_at FROM file_instances')
        .getSingle();
    expect(row.read<String>('integrity'), 'possibly_corrupt');
    expect(row.readNullable<int>('integrity_resolved_at'), isNull);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v6-')), hasLength(1));
  });

  test('v7 → v8: dados preservados, impressões visuais e descartes vazios', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(7);
    schema.rawDatabase
      ..execute(
        "INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) "
        "VALUES (1, zeroblob(32), 10, 'photo', 1)",
      )
      ..execute('PRAGMA user_version = 7')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    expect(await catalog.db.select(catalog.db.contents).get(), hasLength(1));
    expect(await catalog.db.select(catalog.db.visualHashes).get(), isEmpty);
    expect(await catalog.db.select(catalog.db.visualDismissals).get(), isEmpty);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v7-')), hasLength(1));
  });

  test('v8 → v9: metadados preservados, identificador vazio, nenhum item agrupado', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(8);
    schema.rawDatabase
      ..execute(
        "INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) "
        "VALUES (1, zeroblob(32), 10, 'photo', 1)",
      )
      ..execute("INSERT INTO media_metadata (content_id, make, meta_status) VALUES (1, 'Apple', 'full')")
      ..execute('PRAGMA user_version = 8')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final row = await catalog.db.customSelect('SELECT make, content_identifier FROM media_metadata').getSingle();
    expect(row.read<String>('make'), 'Apple');
    expect(row.readNullable<String>('content_identifier'), isNull);
    expect(await catalog.db.select(catalog.db.mediaItems).get(), isEmpty);
    expect(await catalog.db.select(catalog.db.mediaItemMembers).get(), isEmpty);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v8-')), hasLength(1));
  });

  test('v9 → v10: media_metadata refeita com todos os dados e índices; data "Google Fotos" aceita', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(9);
    schema.rawDatabase
      ..execute(
        "INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) "
        "VALUES (1, zeroblob(32), 10, 'photo', 1)",
      )
      ..execute(
        'INSERT INTO media_metadata (content_id, capture_utc_ms, date_source, date_confidence, make, lat, '
        "eff_utc_ms, eff_year, meta_status, content_identifier, candidates_json) "
        "VALUES (1, 1000, 'exif_original', 'high', 'Canon', -23.5, 1000, 2024, 'full', 'A1', '[]')",
      )
      ..execute('PRAGMA user_version = 9')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final db = catalog.db;
    final row = await db
        .customSelect(
          'SELECT capture_utc_ms, date_source, make, lat, eff_year, meta_status, content_identifier, candidates_json '
          'FROM media_metadata',
        )
        .getSingle();
    expect(row.data, {
      'capture_utc_ms': 1000,
      'date_source': 'exif_original',
      'make': 'Canon',
      'lat': -23.5,
      'eff_year': 2024,
      'meta_status': 'full',
      'content_identifier': 'A1',
      'candidates_json': '[]',
    });
    await db.customStatement("UPDATE media_metadata SET date_source = 'takeout'");
    final indexes = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index' AND tbl_name = 'media_metadata'")
        .get();
    expect(indexes.map((r) => r.read<String>('name')), containsAll(['ix_mm_capture', 'ix_mm_eff', 'ix_mm_moment']));
    expect(await db.select(db.takeoutJson).get(), isEmpty);
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v9-')), hasLength(1));
  });

  test('v10 → v11: operations refeita com o histórico inteiro; "Limpar repetidos" aceito', () async {
    final home = await createTestTemp();
    final path = p.join(home.path, 'catalog.db');
    final schema = await verifier.schemaAt(10);
    schema.rawDatabase
      ..execute(
        "INSERT INTO sources (id, name, kind, root_rel_path, connected, created_at, updated_at) "
        "VALUES ('s1', 'HD', 'external_hd', '', 0, 1, 1)",
      )
      ..execute(
        "INSERT INTO file_instances (id, source_id, rel_path, dir_rel_path, name, ext, size_bytes) "
        "VALUES (7, 's1', 'a.jpg', '', 'a.jpg', 'jpg', 10)",
      )
      ..execute(
        'INSERT INTO operations (id, kind, status, dest_source_id, params_json, summary_json, created_at) '
        "VALUES ('op1', 'reorganize_move', 'completed', 's1', '{\"folder\":\"\"}', '{\"published\":1}', 5)",
      )
      ..execute(
        'INSERT INTO operations (id, kind, status, dest_source_id, undo_of, created_at) '
        "VALUES ('op2', 'undo', 'completed', 's1', 'op1', 6)",
      )
      ..execute(
        'INSERT INTO operation_items (id, operation_id, seq, src_source_id, src_rel_path, src_instance_id, '
        'expected_size, dst_source_id, dst_rel_path_planned, state, updated_at) '
        "VALUES (3, 'op1', 1, 's1', 'b.jpg', 7, 10, 's1', 'a.jpg', 'published', 5)",
      )
      ..execute("INSERT INTO operation_events (operation_id, item_id, at, message) VALUES ('op1', 3, 5, 'Movido.')")
      ..execute(
        "INSERT INTO integrity_checks (instance_id, operation_id, checked_at, result) VALUES (7, 'op1', 5, 'unchanged')",
      )
      ..execute('PRAGMA user_version = 10')
      ..execute('VACUUM INTO ?', [path]);
    schema.rawDatabase.close();

    final catalog = await Catalog.open(path);
    addTearDown(catalog.close);
    final db = catalog.db;
    final ops = await db
        .customSelect('SELECT id, kind, status, params_json, summary_json, undo_of FROM operations ORDER BY id')
        .get();
    expect(ops.map((r) => r.data), [
      {
        'id': 'op1',
        'kind': 'reorganize_move',
        'status': 'completed',
        'params_json': '{"folder":""}',
        'summary_json': '{"published":1}',
        'undo_of': null,
      },
      {'id': 'op2', 'kind': 'undo', 'status': 'completed', 'params_json': null, 'summary_json': null, 'undo_of': 'op1'},
    ]);
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM operation_items').getSingle()).read<int>('n'), 1);
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM operation_events').getSingle()).read<int>('n'), 1);
    expect((await db.customSelect('SELECT COUNT(*) AS n FROM integrity_checks').getSingle()).read<int>('n'), 1);
    // As chaves estrangeiras voltaram a valer e continuam apontando para operations.
    expect((await db.customSelect('PRAGMA foreign_keys').getSingle()).data.values.single, 1);
    expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    await expectLater(
      db.customStatement(
        'INSERT INTO operation_items (operation_id, seq, src_source_id, src_rel_path, expected_size, dst_source_id, '
        "dst_rel_path_planned, state, updated_at) VALUES ('nao-existe', 1, 's1', 'x', 1, 's1', 'x', 'pending', 1)",
      ),
      throwsA(anything),
    );
    await db.customStatement(
      "INSERT INTO operations (id, kind, status, created_at) VALUES ('op3', 'dedupe_trash', 'confirmed', 7)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO operations (id, kind, status, created_at) VALUES ('op4', 'apagar', 'confirmed', 7)",
      ),
      throwsA(anything),
    );
    final backups = Directory(p.join(home.path, 'backups')).listSync().map((f) => p.basename(f.path));
    expect(backups.where((n) => n.startsWith('pre-migracao-v10-')), hasLength(1));
  });
}
