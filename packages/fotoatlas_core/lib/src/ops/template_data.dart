import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../metadata/capture_date.dart' show parseWall;
import 'names.dart';

/// Colunas de `media_metadata mm` que os modelos de pasta usam (junte com
/// `LEFT JOIN media_metadata mm ON mm.content_id = …`).
const templateColumnsSql =
    'mm.eff_year, mm.eff_month, mm.eff_day, mm.eff_local, mm.eff_confidence, mm.moment_id, mm.make, mm.model';

/// Nome e início (hora local) de um momento.
class MomentHead {
  const MomentHead(this.name, this.start);
  final String? name;
  final DateTime? start;
}

/// Todos os momentos com o início em hora local (o primeiro item pela hora
/// real), lidos uma vez por prévia.
Future<Map<int, MomentHead>> loadMomentHeads(CatalogDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT m.id, m.name, (SELECT eff_local FROM media_metadata WHERE moment_id = m.id '
        'ORDER BY eff_utc_ms, content_id LIMIT 1) AS first_local FROM moments m',
        readsFrom: {db.moments, db.mediaMetadata},
      )
      .get();
  return {
    for (final r in rows)
      r.read<int>('id'): MomentHead(r.readNullable<String>('name'), parseWall(r.readNullable<String>('first_local'))),
  };
}

/// Variáveis do modelo a partir de uma linha com [templateColumnsSql].
TemplateVars templateVarsFrom(
  QueryRow r, {
  required String originalDir,
  required String mediaType,
  String? sourceName,
  required Map<int, MomentHead> moments,
}) {
  final day = r.readNullable<String>('eff_day');
  final local = parseWall(r.readNullable<String>('eff_local'));
  final make = r.readNullable<String>('make'), model = r.readNullable<String>('model');
  final momentId = r.readNullable<int>('moment_id');
  final moment = momentId == null ? null : moments[momentId];
  return TemplateVars(
    year: r.readNullable<int>('eff_year'),
    month: r.readNullable<int>('eff_month'),
    day: day == null || day.length < 10 ? null : int.tryParse(day.substring(8, 10)),
    hour: local?.hour,
    minute: local?.minute,
    second: local?.second,
    originalDir: originalDir,
    mediaType: mediaType,
    camera: model ?? make,
    sourceName: sourceName,
    momentStart: moment?.start,
    momentName: moment?.name,
  );
}
