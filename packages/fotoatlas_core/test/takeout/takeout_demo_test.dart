import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

/// O que a demonstração "Google Takeout" (`run-app.ps1 -DemoPersistente`)
/// mostra: o roteiro `docs\roteiro-teste-fase-9.md` descreve estes resultados.
void main() {
  test('demonstração "Google Takeout": pasta e zips do roteiro de teste', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    generateTakeoutDemo(p.join(env.volumeDir.path, 'Google Takeout'));
    final pasta = await env.addFolder('Google Takeout/Pasta', name: 'Pasta');
    final zips = await env.addFolder('Google Takeout/Zips', name: 'Zips');
    final hd = await env.addFolder('Destino Takeout', name: 'Destino Takeout');
    for (final s in [pasta, zips, hd]) {
      await env.scan(s);
    }
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.metadata.waitIdle();
    await env.core.settleDates();

    Future<LibraryItem> item(String name) async {
      final id =
          (await env.db
                  .customSelect(
                    'SELECT content_id FROM file_instances WHERE name = ?',
                    variables: [Variable.withString(name)],
                  )
                  .getSingle())
              .read<int>('content_id');
      return (await env.core.library.items([id])).single;
    }

    String when(LibraryItem i) => DateTime.fromMillisecondsSinceEpoch(i.utcMs!, isUtc: true).toIso8601String();
    final a = await item('IMG_0001.jpg');
    expect(when(a), '2023-07-22T13:05:00.000Z');
    expect(a.hasGps, isTrue);
    expect(when(await item('IMG_0002(1).jpg')), '2023-07-22T14:30:00.000Z');
    expect(when(await item('IMG_0003-editado.jpg')), '2023-07-23T09:00:00.000Z');
    expect((await item('sem_json.jpg')).uncertain, isTrue);

    final found = await env.core.takeoutZips.find(sourceId: zips);
    expect(found, hasLength(2));
    final preview = await env.core.takeoutZips.preview(found, destSourceId: hd);
    expect(TakeoutZips.countKinds(preview), (media: 2, json: 2, other: 0));
    await env.core.copies.start(preview);
    await env.core.copies.waitIdle();
    await env.core.metadata.start();
    await env.core.metadata.waitIdle();
    await env.core.settleDates();
    expect(when(await item('IMG_0101.jpg')), '2024-03-09T21:15:00.000Z');
    expect(when(await item('IMG_0102.jpg')), '2024-03-09T21:40:00.000Z');
  });
}
