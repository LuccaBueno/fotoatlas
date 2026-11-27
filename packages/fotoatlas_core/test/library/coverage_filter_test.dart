import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 31 + seed * 7 + (i >> 5)) & 0xff);

/// O filtro "situação no dispositivo" (números clicáveis dos cartões e do
/// Início): a Biblioteca mostra exatamente o que o número conta, inclusive
/// arquivos ainda não conferidos.
void main() {
  test('cada número do cartão bate com a Biblioteca filtrada por dispositivo e situação', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final other = env.addVolume('B');
    env
      ..write('HD/so_aqui.jpg', bytes(1, 3000))
      ..write('HD/nos_dois.jpg', bytes(2, 4000))
      ..write('HD/so_aqui_2.jpg', bytes(3, 5000))
      ..write('HD/vai_conferir.jpg', bytes(4, 6000))
      ..write('B/nos_dois.jpg', bytes(2, 4000), volume: other)
      ..write('B/vai_conferir.jpg', bytes(4, 6000), volume: other);
    final hd = await env.addFolder('HD', name: 'HD');
    final b = await env.addFolder('B', name: 'Backup', volume: other);
    await env.scan(hd);
    await env.scan(b);

    Future<void> expectMatches() async {
      final c = (await env.core.coverage.report()).perSource[hd]!;
      for (final state in BackupState.values) {
        final index = await env.core.library.index(
          LibraryFilter([
            FilterCondition(FilterKind.sources, values: [hd]),
            FilterCondition(FilterKind.coverage, values: [state.name]),
          ]),
        );
        expect(index.length, c.counts.filesIn(state), reason: state.name);
      }
    }

    // Nada conferido: "só aqui" pelo tamanho único, "provável" pelo nome e tamanho.
    await expectMatches();
    final probable = await env.core.library.index(
      const LibraryFilter([
        FilterCondition(FilterKind.coverage, values: ['probable']),
      ]),
    );
    expect(probable.length, 4, reason: 'os dois pares (nome e tamanho iguais) nos dois dispositivos');

    // Tudo conferido: "com cópia em outro disco" e "só aqui".
    await env.hashAll();
    await expectMatches();
    final c = (await env.core.coverage.report()).perSource[hd]!;
    expect(c.counts.filesIn(BackupState.single), 2);
    expect(c.counts.filesIn(BackupState.independent) + c.counts.filesIn(BackupState.verified), 2);

    // O filtro vai e volta pelo JSON dos filtros salvos.
    const f = LibraryFilter([
      FilterCondition(FilterKind.coverage, values: ['single']),
    ]);
    expect(LibraryFilter.fromJson(f.toJson()).conditions.single.kind, FilterKind.coverage);
  });
}
