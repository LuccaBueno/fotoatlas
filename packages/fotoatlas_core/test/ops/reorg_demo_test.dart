import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';
import '../support/tools.dart';

/// O "HD bagunçado" da demonstração (`run-app.ps1 -DemoPersistente`) gera a
/// árvore anunciada no roteiro de teste, com e sem ExifTool.
void main() {
  final tools = ExternalTools.locate();

  Future<void> check(ExternalTools t) async {
    final env = await TestEnv.open(tools: t);
    generateReorgDemo(p.join(env.volumeDir.path, 'HD bagunçado'));
    final hd = await env.addFolder('HD bagunçado', name: 'HD bagunçado');
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final preview = await env.core.reorg.preview(ReorgRequest(sourceId: hd));
    expect(preview.blocker, isNull);
    expect(
      {for (final m in preview.moves) m.srcRelPath: m.dstRelPath},
      {
        'Downloads antigos/IMG_20240713_140300.jpg': '2024/2024-07-13 14h03/IMG_20240713_140300.jpg',
        'Downloads antigos/IMG_20240713_140300.xmp': '2024/2024-07-13 14h03/IMG_20240713_140300.xmp',
        'Downloads antigos/sub/IMG_20240713_151000.jpg': '2024/2024-07-13 14h03/IMG_20240713_151000.jpg',
        'Pendrive da tia/IMG_20240713_162000.jpg': '2024/2024-07-13 14h03/IMG_20240713_162000.jpg',
        'Pendrive da tia/IMG_20240820_093000.jpg': '2024/2024-08-20 09h30/IMG_20240820_093000_1.jpg',
        'Pendrive da tia/VID_20240820_094500.mp4': '2024/2024-08-20 09h30/VID_20240820_094500.mp4',
        'Pendrive da tia/IMG_20241231_233000.jpg': '2024/2024-12-31 23h30/IMG_20241231_233000.jpg',
        'Pendrive da tia/IMG_20250101_001500.jpg': '2024/2024-12-31 23h30/IMG_20250101_001500.jpg',
        'Velhas/IMG_20240820_100000.jpg': '2024/2024-08-20 09h30/IMG_20240820_100000.jpg',
        'Sem nome/foto_escaneada.jpg': '$undatedFolder/foto_escaneada.jpg',
      },
    );
    expect(preview.alreadyInPlace, 1);
    expect(preview.otherFiles, 2, reason: 'lista de compras.txt e Thumbs.db');
    final op = await env.core.reorg.start(preview);
    await env.core.reorg.waitIdle();
    final folders = await env.core.reorg.emptyFolders(op);
    expect(
      {for (final f in folders) f.relPath: f.empty},
      {'Downloads antigos': true, 'Downloads antigos/sub': true, 'Pendrive da tia': true, 'Velhas': false},
    );
  }

  test('sem ExifTool (datas do nome do arquivo)', () => check(ExternalTools.none));
  test(
    'com ExifTool (datas do EXIF e do vídeo)',
    () => check(tools),
    skip: skipWithoutTool(tools.exiftool, 'ExifTool'),
  );
}
