import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 31 + seed * 7) & 0xff);

void main() {
  test('logo depois do escaneamento: itens "conferindo…" com a data do nome ou do arquivo, '
      'que viram itens normais quando a conferência termina', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    env
      ..write('DCIM/IMG_20240713_140300.jpg', bytes(1, 3000))
      ..write('DCIM/VID_20240713_150000.mp4', bytes(2, 4000))
      ..write('DCIM/notas.txt', bytes(3, 50));
    env.write('DCIM/sem_nome.jpg', bytes(4, 900)).setLastModifiedSync(DateTime.utc(2023, 5, 6, 15));
    final hd = await env.addFolder('DCIM', name: 'Celular antigo');
    await env.scan(hd);
    final lib = env.core.library;

    // Nada conferido ainda: a Biblioteca já mostra as 3 fotos e vídeos.
    var index = await lib.index(LibraryFilter.empty);
    expect(index.length, 3);
    expect(index.provisionalCount, 3);
    expect(index.ids.every(LibraryIndex.isProvisional), isTrue);
    final items = {for (final i in await lib.items(index.ids.toList())) i.name: i};
    expect(items.keys, unorderedEquals(['IMG_20240713_140300.jpg', 'VID_20240713_150000.mp4', 'sem_nome.jpg']));
    expect(items.values.every((i) => i.provisional && i.backup == BackupState.unknown), isTrue);
    expect(items['IMG_20240713_140300.jpg']!.local, DateTime.utc(2024, 7, 13, 14, 3));
    expect(items['IMG_20240713_140300.jpg']!.dateSource, DateSource.filename);
    expect(items['VID_20240713_150000.mp4']!.mediaType, 'video');
    expect(items['sem_nome.jpg']!.dateSource, DateSource.filesystem);
    expect(items['sem_nome.jpg']!.places, ['Celular antigo']);
    // Mais recente primeiro; o dia da linha do tempo vem da data provisória.
    expect(index.day.first, 20240713);
    expect(index.day.last, 20230506);
    final detail = await lib.detail(index.ids.first);
    expect(detail!.item.provisional, isTrue);
    expect(detail.locations.single.relPath, 'VID_20240713_150000.mp4');

    // Filtros que o escaneamento já responde continuam mostrando os provisórios…
    index = await lib.index(
      const LibraryFilter([
        FilterCondition(FilterKind.types, values: ['video']),
      ]),
    );
    expect(index.provisionalCount, 1);
    index = await lib.index(
      LibraryFilter([
        FilterCondition(FilterKind.sources, values: [hd], negate: true),
      ]),
    );
    expect(index.length, 0);
    // …os que dependem da conferência (backup, data efetiva…) esperam por ela.
    index = await lib.index(
      const LibraryFilter([
        FilterCondition(FilterKind.backup, values: ['single']),
      ]),
    );
    expect(index.length, 0);

    // Conferência e datas: os mesmos itens, agora normais (sem duplicar).
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    index = await lib.index(LibraryFilter.empty);
    expect(index.length, 3);
    expect(index.provisionalCount, 0);
    expect(index.ids.any(LibraryIndex.isProvisional), isFalse);
    expect((await lib.items(index.ids.toList())).every((i) => !i.provisional), isTrue);
  });

  test('momento que atravessa a meia-noite aparece uma vez, no dia em que começa; '
      'um provisório no meio dele fica no mesmo momento', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    env
      ..write('Fotos/IMG_20241231_233000.jpg', bytes(1, 1000))
      ..write('Fotos/IMG_20250101_001500.jpg', bytes(2, 1100))
      ..write('Fotos/IMG_20250103_100000.jpg', bytes(3, 1200));
    final hd = await env.addFolder('Fotos', name: 'HD');
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final lib = env.core.library;

    for (final ascending in [false, true]) {
      final index = await lib.index(LibraryFilter.empty, ascending: ascending);
      final byDay = <int, Set<int>>{};
      for (var i = 0; i < index.length; i++) {
        byDay.putIfAbsent(index.day[i], () => {}).add(index.moment[i]);
      }
      expect(byDay.keys, unorderedEquals([20241231, 20250103]), reason: 'ascending: $ascending');
      expect(byDay[20241231], hasLength(1), reason: 'as duas fotos no mesmo momento');
    }

    // Foto nova no meio do momento, escaneada mas ainda não conferida.
    env.write('Fotos/IMG_20250101_000000.jpg', bytes(4, 1300));
    await env.scan(hd);
    final index = await lib.index(LibraryFilter.empty);
    expect(index.provisionalCount, 1);
    final k = index.ids.indexWhere(LibraryIndex.isProvisional);
    expect(index.moment[k], index.moment[k - 1]);
    expect(index.moment[k], index.moment[k + 1]);
    expect(index.day[k], 20241231);
  });
}
