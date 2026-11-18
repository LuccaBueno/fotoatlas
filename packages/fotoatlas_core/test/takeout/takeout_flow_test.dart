import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);

List<int> sidecar(String title, int ts, {double lat = -23.55, double lon = -46.63}) => utf8.encode(
  jsonEncode({
    'title': title,
    'photoTakenTime': {'timestamp': '$ts', 'formatted': 'não usado'},
    'geoData': {'latitude': lat, 'longitude': lon, 'altitude': 0.0},
  }),
);

Map<String, String> snapshot(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    f.path: '${sha256.convert(f.readAsBytesSync())} ${f.lastModifiedSync().millisecondsSinceEpoch}',
};

void main() {
  test('Takeout em pasta: data e local do .json só no catálogo; sem .json = hora a confirmar', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    const album = 'Takeout/Google Fotos/Viagem 2023';
    env
      ..write('$album/IMG_0001.JPG', bytes(1, 2000))
      ..write('$album/IMG_0001.JPG.supplemental-metadata.json', sidecar('IMG_0001.JPG', 1690000000))
      ..write('$album/IMG_0002(1).JPG', bytes(2, 2100))
      ..write('$album/IMG_0002.JPG(1).json', sidecar('IMG_0002.JPG', 1690000600, lat: 0, lon: 0))
      // Sem .json, com data no nome: mesmo assim, hora a confirmar.
      ..write('$album/IMG_20230722_101010.jpg', bytes(3, 2200))
      ..write('$album/metadados.json', utf8.encode('{"title": "Viagem 2023", "date": {}}'))
      // Fora do Takeout, o mesmo tipo de nome continua confiável.
      ..write('Outros/IMG_20230722_111111.jpg', bytes(4, 2300));
    final root = Directory(p.join(env.volumeDir.path, 'Takeout'));
    final before = snapshot(root);
    final hd = await env.addFolder('', name: 'HD');
    await env.scan(hd);
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

    final a = await item('IMG_0001.JPG');
    expect(a.utcMs, 1690000000000);
    expect(a.dateSource, DateSource.takeout);
    expect(a.uncertain, isFalse);
    expect(a.hasGps, isTrue, reason: 'local do .json');
    final b = await item('IMG_0002(1).JPG');
    expect(b.utcMs, 1690000600000, reason: '"(1)" casa com o .json "(1)"');
    expect(b.hasGps, isFalse, reason: '(0, 0) não é local');
    final c = await item('IMG_20230722_101010.jpg');
    expect(c.dateSource, DateSource.filename);
    expect(c.uncertain, isTrue, reason: 'pasta do Takeout sem .json');
    final d = await item('IMG_20230722_111111.jpg');
    expect(d.uncertain, isFalse);
    // A ordem salva antes da origem nova continua valendo, com ela no meio.
    expect(env.core.metadata.priority, contains(DateSource.takeout));

    // .json que chega depois (outra parte do Takeout): a data entra na próxima leitura.
    env.write('$album/IMG_20230722_101010.jpg.json', sidecar('IMG_20230722_101010.jpg', 1690020000));
    await env.scan(hd);
    await env.core.metadata.start();
    await env.core.metadata.waitIdle();
    await env.core.settleDates();
    final c2 = await item('IMG_20230722_101010.jpg');
    expect(c2.dateSource, DateSource.takeout);
    expect(c2.uncertain, isFalse);

    // Nenhum arquivo mudou (conteúdo e data de modificação).
    final after = snapshot(root)..removeWhere((k, _) => k.endsWith('IMG_20230722_101010.jpg.json'));
    expect(after, before);
  });
}
