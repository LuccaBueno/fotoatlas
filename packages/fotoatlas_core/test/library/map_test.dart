import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);

void main() {
  test('mapa: pontos do catálogo e filtro por área (também atravessando a linha de data)', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    const places = {
      'rio.jpg': (-22.90, -43.20),
      'sp.jpg': (-23.55, -46.63),
      'lisboa.jpg': (38.72, -9.14),
      'toquio.jpg': (35.68, 139.69),
      'fiji_oeste.jpg': (-17.7, 178.0),
      'fiji_leste.jpg': (-16.5, -179.8),
    };
    var seed = 0;
    for (final name in [...places.keys, 'sem_local.jpg']) {
      env.write('F/$name', bytes(seed++, 1000 + seed));
    }
    final hd = await env.addFolder('F');
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final ids = <String, int>{};
    for (final name in [...places.keys, 'sem_local.jpg']) {
      ids[name] =
          (await env.db
                  .customSelect(
                    'SELECT content_id FROM file_instances WHERE name = ?',
                    variables: [Variable.withString(name)],
                  )
                  .getSingle())
              .read<int>('content_id');
    }
    for (final MapEntry(key: name, value: (lat, lon)) in places.entries) {
      await env.db.customStatement('UPDATE media_metadata SET lat = ?, lon = ? WHERE content_id = ?', [
        lat,
        lon,
        ids[name],
      ]);
    }

    final all = await env.core.library.mapPoints(LibraryFilter.empty);
    expect(all.length, 6, reason: 'a foto sem local não aparece');
    final i = all.ids.indexOf(ids['rio.jpg']!);
    expect((all.lat[i], all.lon[i]), (-22.90, -43.20));

    Future<Set<String>> inArea(double s, double n, double w, double e) async {
      final f = LibraryFilter([
        FilterCondition(FilterKind.area, values: [s, n, w, e]),
      ]);
      final idx = await env.core.library.index(f);
      return {
        for (final MapEntry(:key, :value) in ids.entries)
          if (idx.ids.contains(value)) key,
      };
    }

    expect(await inArea(-34, 5, -74, -34), {'rio.jpg', 'sp.jpg'}, reason: 'Brasil');
    expect(await inArea(-30, -10, 170, -170), {'fiji_oeste.jpg', 'fiji_leste.jpg'}, reason: 'linha de data');
    expect(
      (await env.core.library.mapPoints(
        const LibraryFilter([
          FilterCondition(FilterKind.area, values: [30, 45, -15, 145]),
        ]),
      )).length,
      2,
    );
    // Filtro salvo com área volta igual.
    final f = LibraryFilter([
      FilterCondition(FilterKind.area, values: [-34.0, 5.0, -74.0, -34.0]),
    ]);
    expect(LibraryFilter.fromJson(f.toJson()).conditions.single, f.conditions.single);
  });
}
