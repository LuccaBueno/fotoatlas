import 'package:drift/drift.dart';

part 'catalog_database.g.dart';

/// Banco do catálogo (schema em `schema.drift`, documentado em
/// `docs/schema-v1.md`). Pragmas, checagem de versão e backup antes de
/// migração ficam em `catalog.dart`, antes de o drift abrir a conexão.
@DriftDatabase(include: {'schema.drift'})
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  static const int currentSchemaVersion = 2;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    // Cada passo vN→vN+1 roda dentro da transação de migração do drift: se
    // falhar, nada muda. Só mudanças aditivas (docs/schema-v1.md §3).
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(fileInstances, fileInstances.hashError);
        await m.createTable(savedScopes);
      }
    },
  );
}
