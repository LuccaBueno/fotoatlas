import 'package:drift/drift.dart';

part 'catalog_database.g.dart';

/// Banco do catálogo (schema em `schema.drift`, documentado em
/// `docs/schema-v1.md`). Pragmas, checagem de versão e backup antes de
/// migração ficam em `catalog.dart`, antes de o drift abrir a conexão.
@DriftDatabase(include: {'schema.drift'})
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  static const int currentSchemaVersion = 1;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Não há migrações ainda. Cada passo futuro vN→vN+1 entra aqui e roda
      // dentro da transação de migração do drift.
      throw StateError('Migração de v$from para v$to não implementada.');
    },
  );
}
