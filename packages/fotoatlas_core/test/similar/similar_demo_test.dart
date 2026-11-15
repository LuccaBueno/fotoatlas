import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

/// O que a pasta de demonstração (`run-app.ps1 -DemoPersistente`) mostra: o
/// roteiro `docs\roteiro-teste-fase-9.md` descreve exatamente estes grupos.
void main() {
  test('demonstração "Fotos parecidas": os grupos do roteiro de teste', () async {
    final env = await TestEnv.open();
    generateSimilarDemo(p.join(env.volumeDir.path, 'Fotos parecidas'));
    final source = await env.addFolder('Fotos parecidas');
    await env.scan(source);
    await env.hashAll();
    await env.core.similar.start();

    /// "nível: arquivo, arquivo…" de cada grupo, na ordem da tela.
    Future<List<String>> describe(SimilarLevel min) async => [
      for (final g in await env.core.similar.groups(minLevel: min))
        '${g.level.name}: ${[for (final id in g.contentIds) (await env.db.customSelect('SELECT rel_path FROM file_instances WHERE content_id = $id').getSingle()).read<String>('rel_path')]..sort()}',
    ];

    expect(await describe(SimilarLevel.maybe), [
      'nearIdentical: [Praia/IMG_0101.jpg, Praia/IMG_0101_compartilhada.jpg, Praia/IMG_0101_editada.jpg, '
          'WhatsApp/IMG-20240712-WA0003.jpg]',
      'high: [Festa/IMG_0201.jpg, Festa/IMG_0202.jpg]',
      'high: [Viagem/IMG_0301.jpg, Viagem/IMG_0301_recorte.jpg]',
    ]);
    // "Só quase idênticas": fica só a praia.
    expect(await describe(SimilarLevel.nearIdentical), hasLength(1));
    expect(await env.count('SELECT COUNT(*) FROM visual_hashes WHERE flat = 1'), 1, reason: 'tela preta');
    expect(await env.count('SELECT COUNT(*) FROM visual_hashes'), 11);
  });
}
