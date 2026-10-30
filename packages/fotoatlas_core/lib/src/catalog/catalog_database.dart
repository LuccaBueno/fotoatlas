import 'package:drift/drift.dart';

part 'catalog_database.g.dart';

/// Banco do catálogo (schema em `schema.drift`, documentado em
/// `docs/schema-v1.md`). Pragmas, checagem de versão e backup antes de
/// migração ficam em `catalog.dart`, antes de o drift abrir a conexão.
@DriftDatabase(include: {'schema.drift'})
class CatalogDatabase extends _$CatalogDatabase {
  CatalogDatabase(super.e);

  static const int currentSchemaVersion = 5;

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
      if (from < 3) {
        await m.addColumn(sources, sources.deviceSerial);
        await m.addColumn(sources, sources.devicePlatform);
        await m.addColumn(fileInstances, fileInstances.deviceObjectId);
      }
      if (from < 4) {
        await m.createTable(moments);
        await m.createIndex(ixMomentsStart);
        await m.createTable(momentEdits);
        await m.createTable(clockCorrections);
        for (final c in [
          mediaMetadata.bodySerial,
          mediaMetadata.metaStatus,
          mediaMetadata.metaError,
          mediaMetadata.effUtcMs,
          mediaMetadata.effLocal,
          mediaMetadata.effOffsetMin,
          mediaMetadata.effSource,
          mediaMetadata.effConfidence,
          mediaMetadata.clockCorrectionId,
          mediaMetadata.effYear,
          mediaMetadata.effMonth,
          mediaMetadata.effDay,
          mediaMetadata.effMinute,
          mediaMetadata.effWeekday,
          mediaMetadata.momentId,
        ]) {
          await m.addColumn(mediaMetadata, c);
        }
        await m.createIndex(ixMmEff);
        await m.createIndex(ixMmYm);
        await m.createIndex(ixMmMoment);
      }
      if (from < 5) {
        await m.addColumn(operationItems, operationItems.expectedMtime);
        await m.addColumn(operationItems, operationItems.undoOfItemId);
      }
    },
  );
}
