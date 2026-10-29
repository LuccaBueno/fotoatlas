import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

void main() {
  test('fonte dentro de outra: o mesmo arquivo visto duas vezes continua sendo 1 cópia', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final pasta = await env.addFolder('Fotos', name: 'Fotos');
    final hd = (await env.core.sources.addPath(env.volumeDir.path, name: 'HD inteiro')).sourceId;
    env
      ..write('Fotos/a.jpg', [1, 2, 3])
      ..write('Fotos/b.jpg', [4, 5, 6])
      ..write('Outra/b-copia.jpg', [4, 5, 6]);
    await env.scan(pasta);
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    final lib = env.core.library;
    expect(await lib.count(LibraryFilter.empty), 2);
    const single = LibraryFilter([
      FilterCondition(FilterKind.backup, values: ['single']),
    ]);
    const verified = LibraryFilter([
      FilterCondition(FilterKind.backup, values: ['verified']),
    ]);
    expect(await lib.count(single), 1, reason: 'a.jpg: duas fontes, um arquivo só');
    expect(await lib.count(verified), 1, reason: 'b.jpg tem cópia em outra pasta');
    final items = await lib.items((await lib.index(LibraryFilter.empty)).ids.toList());
    expect({for (final i in items) i.name: i.backup}, {'a.jpg': BackupState.single, 'b.jpg': BackupState.verified});
    expect(items.firstWhere((i) => i.name == 'a.jpg').places, ['Fotos', 'HD inteiro']);
  });

  test('filtro vai e volta do JSON (filtros salvos); condição desconhecida é ignorada', () {
    const f = LibraryFilter([
      FilterCondition(FilterKind.years, values: [2024]),
      FilterCondition(FilterKind.timeRange, min: 1320, max: 240, negate: true),
      FilterCondition(FilterKind.text, text: 'praia'),
    ], true);
    final back = LibraryFilter.fromJson(f.toJson());
    expect(back.any, isTrue);
    expect(back.conditions, f.conditions);
    final future = LibraryFilter.fromJson('{"v":2,"conds":[{"t":"novidade"},{"t":"years","v":[2020]}]}');
    expect(future.conditions.single.kind, FilterKind.years);
  });
}
