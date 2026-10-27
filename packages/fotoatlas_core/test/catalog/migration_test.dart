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

  test('v2 → v3 e v1 → v3: schema final igual ao de um catálogo novo', () async {
    for (final from in [1, 2]) {
      final schema = await verifier.schemaAt(from);
      final db = CatalogDatabase(schema.newConnection());
      await verifier.migrateAndValidate(db, 3);
      await db.close();
    }
  });

  test('v1 → v3 pelo Catalog.open: backup antes, dados preservados, colunas novas', () async {
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
    expect((await db.customSelect('PRAGMA user_version').getSingle()).data.values.single, 3);
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
}
