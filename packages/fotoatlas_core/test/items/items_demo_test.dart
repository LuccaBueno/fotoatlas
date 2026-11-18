import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';
import '../support/tools.dart';

/// O que a pasta de demonstração (`run-app.ps1 -DemoPersistente`) mostra: o
/// roteiro `docs\roteiro-teste-fase-9.md` descreve exatamente estes itens.
void main() {
  test('demonstração "Fotos agrupadas": os itens do roteiro de teste', () async {
    final env = await TestEnv.open();
    generateItemsDemo(p.join(env.volumeDir.path, 'Fotos agrupadas'));
    final source = await env.addFolder('Fotos agrupadas');
    await env.scan(source);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();

    Future<String> path(int id) async =>
        (await env.db.customSelect('SELECT rel_path FROM file_instances WHERE content_id = $id').getSingle())
            .read<String>('rel_path');
    final items = [
      for (final item in await env.core.items.all())
        '${item.kind.sql}: ${[for (final m in item.members) await path(m.contentId)]..sort()}',
    ]..sort();
    expect(items, [
      'live_photo: [iPhone/IMG_2001.JPG, iPhone/IMG_2001.MOV]',
      'raw_jpeg: [Câmera/IMG_1001.DNG, Câmera/IMG_1001.JPG]',
      'raw_jpeg: [Câmera/IMG_1002.DNG, Câmera/IMG_1002.JPG]',
    ]);
    // Na Biblioteca: 3 itens agrupados + o vídeo longo, a foto dele e a sozinha.
    expect(await env.core.library.count(LibraryFilter.empty), 6);
    // A Live Photo pelo nome precisa da duração do vídeo (ExifTool/ffprobe).
  }, skip: skipWithoutTool(ExternalTools.locate().exiftool, 'ExifTool'));
}
