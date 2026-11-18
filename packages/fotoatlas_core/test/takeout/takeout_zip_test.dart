import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);

List<int> sidecar(String title, int ts) => utf8.encode(
  jsonEncode({
    'title': title,
    'photoTakenTime': {'timestamp': '$ts'},
    'geoData': {'latitude': -22.9, 'longitude': -43.2},
  }),
);

Uint8List zipOf(Map<String, List<int>> files) {
  final a = Archive();
  for (final MapEntry(:key, :value) in files.entries) {
    a.addFile(ArchiveFile(key, value.length, value));
  }
  return ZipEncoder().encodeBytes(a);
}

String fingerprint(File f) => '${sha256.convert(f.readAsBytesSync())} ${f.lastModifiedSync().millisecondsSinceEpoch}';

void main() {
  test('zip do Takeout: só lido; extração pela cópia segura; datas do .json só no catálogo', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    const album = 'Takeout/Google Fotos/Praia';
    final json1 = sidecar('IMG_0001.JPG', 1680000000);
    // Parte 1: a foto 1, o .json dela e a foto 2 (o .json da 2 está na parte 2).
    env.write(
      'Downloads/takeout-20240101T000000Z-001.zip',
      zipOf({
        '$album/IMG_0001.JPG': bytes(1, 300000),
        '$album/IMG_0001.JPG.json': json1,
        '$album/IMG_0002.JPG': bytes(2, 5000),
        '$album/metadados.json': utf8.encode('{"title": "Praia"}'),
      }),
    );
    env.write(
      'Downloads/takeout-20240101T000000Z-002.zip',
      zipOf({
        '$album/IMG_0002.JPG.json': sidecar('IMG_0002.JPG', 1680003600),
        // Repetido nas duas partes, igual: extraído uma vez só.
        '$album/IMG_0001.JPG.json': json1,
        'Takeout/arquivo_navegador.html': utf8.encode('<html></html>'),
      }),
    );
    final downloads = await env.addFolder('Downloads', name: 'Downloads');
    final hd = await env.addFolder('HD', name: 'HD');
    await env.scan(downloads);
    await env.scan(hd);
    final zipFiles = Directory(p.join(env.volumeDir.path, 'Downloads')).listSync().whereType<File>().toList();
    final before = {for (final f in zipFiles) f.path: fingerprint(f)};

    final zips = await env.core.takeoutZips.find(sourceId: downloads);
    expect(zips.map((z) => z.name), ['takeout-20240101T000000Z-001.zip', 'takeout-20240101T000000Z-002.zip']);
    final preview = await env.core.takeoutZips.preview(zips, destSourceId: hd);
    expect(preview.blocker, isNull);
    expect(
      {for (final i in preview.items) i.dstRelPath},
      {
        'Google Fotos (Takeout)/Google Fotos/Praia/IMG_0001.JPG',
        'Google Fotos (Takeout)/Google Fotos/Praia/IMG_0001.JPG.json',
        'Google Fotos (Takeout)/Google Fotos/Praia/IMG_0002.JPG',
        'Google Fotos (Takeout)/Google Fotos/Praia/metadados.json',
        'Google Fotos (Takeout)/Google Fotos/Praia/IMG_0002.JPG.json',
        'Google Fotos (Takeout)/arquivo_navegador.html',
      },
    );
    expect(TakeoutZips.countKinds(preview), (media: 2, json: 3, other: 1));
    expect(await env.count('SELECT COUNT(*) FROM operations'), 0, reason: 'a prévia não grava nada');

    final op = await env.core.copies.start(preview);
    await env.core.copies.waitIdle();
    final view = (await env.core.copies.view(op))!;
    expect(view.status, OpStatus.completed);
    expect(view.published, 6);
    final out = p.join(env.volumeDir.path, 'HD', 'Google Fotos (Takeout)', 'Google Fotos', 'Praia');
    expect(
      sha256.convert(File(p.join(out, 'IMG_0001.JPG')).readAsBytesSync()).toString(),
      sha256.convert(bytes(1, 300000)).toString(),
    );

    // A pasta extraída é um Takeout em pasta: datas e locais dos .json.
    await env.core.metadata.start();
    await env.core.metadata.waitIdle();
    await env.core.settleDates();
    Future<LibraryItem> item(String name) async {
      final id =
          (await env.db
                  .customSelect(
                    'SELECT content_id FROM file_instances WHERE name = ? AND source_id = ?',
                    variables: [Variable.withString(name), Variable.withString(hd)],
                  )
                  .getSingle())
              .read<int>('content_id');
      return (await env.core.library.items([id])).single;
    }

    expect((await item('IMG_0001.JPG')).utcMs, 1680000000000);
    expect((await item('IMG_0002.JPG')).utcMs, 1680003600000, reason: 'o .json estava na outra parte');
    expect((await item('IMG_0002.JPG')).hasGps, isTrue);

    // Os zips não mudaram (conteúdo e data).
    expect({for (final f in zipFiles) f.path: fingerprint(f)}, before);

    // Extrair de novo: os nomes já existem, então tudo ganharia _1 — nada é sobrescrito.
    final again = await env.core.takeoutZips.preview(zips, destSourceId: hd);
    expect(again.items.every((i) => i.renamedForConflict), isTrue);
  });

  test('entrada danificada dentro do zip: item falha, nada é publicado', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final a = Archive()..addFile(ArchiveFile.noCompress('Takeout/Google Fotos/x.jpg', 4000, bytes(5, 4000)));
    final zip = ZipEncoder().encodeBytes(a);
    // Troca um byte do conteúdo (guardado sem compressão): o CRC não confere.
    final at = _indexOf(zip, bytes(5, 16));
    zip[at + 100] ^= 0xff;
    env.write('Downloads/takeout-x-001.zip', zip);
    final downloads = await env.addFolder('Downloads', name: 'Downloads');
    final hd = await env.addFolder('HD', name: 'HD');
    await env.scan(downloads);
    await env.scan(hd);
    final preview = await env.core.takeoutZips.preview(await env.core.takeoutZips.find(), destSourceId: hd);
    final op = await env.core.copies.start(preview);
    await env.core.copies.waitIdle();
    final view = (await env.core.copies.view(op))!;
    expect(view.failed, 1);
    final items = await env.core.copies.items(op);
    expect(items.single.errorCode, 'zip_crc');
    expect(
      File(p.join(env.volumeDir.path, 'HD', 'Google Fotos (Takeout)', 'Google Fotos', 'x.jpg')).existsSync(),
      isFalse,
    );
    // O .part descartado não fica para trás.
    final tmp = Directory(p.join(env.volumeDir.path, 'HD', '.fotoatlas-tmp'));
    expect(tmp.existsSync() ? tmp.listSync() : const [], isEmpty);
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var ok = true;
    for (var j = 0; j < needle.length && ok; j++) {
      ok = haystack[i + j] == needle[j];
    }
    if (ok) return i;
  }
  throw StateError('não achou');
}
