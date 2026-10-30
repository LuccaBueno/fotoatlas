import 'dart:convert';
import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await Directory.systemTemp.createTemp('fotoatlas_fixtures_'));
  tearDown(() async => temp.delete(recursive: true));

  test('gera a quantidade pedida de forma determinística', () {
    final a = generateTree(p.join(temp.path, 'a'), const FixtureOptions(files: 300, seed: 7));
    final b = generateTree(p.join(temp.path, 'b'), const FixtureOptions(files: 300, seed: 7));
    expect(a.files, 301, reason: '300 + 1 arquivo de caminho longo');
    expect(a.relPaths, b.relPaths);
    expect(a.bytes, b.bytes);
    // Prefixo \\?\ porque o listSync do Dart falha acima de 260 caracteres.
    final onDisk = Directory('\\\\?\\${a.root}').listSync(recursive: true).whereType<File>().length;
    expect(onDisk, a.files);
  });

  test('inclui caminho longo, Unicode e cópias idênticas', () {
    final m = generateTree(p.join(temp.path, 'c'), const FixtureOptions(files: 200));
    expect(p.join(m.root, m.longPathFile!).length, greaterThan(260));
    expect(m.relPaths.any((r) => r.contains('日本旅行')), isTrue);
    expect(m.identicalPairs, isNotEmpty);
    final (x, y) = m.identicalPairs.first;
    expect(File(p.join(m.root, x)).readAsBytesSync(), File(p.join(m.root, y)).readAsBytesSync());
  });

  test('recusa pasta fora das áreas permitidas', () {
    expect(() => generateTree(r'C:\NaoPermitido\fixtures'), throwsStateError);
  });

  test('recusa pasta de saída não vazia', () {
    File(p.join(temp.path, 'existente.txt')).writeAsStringSync('x');
    expect(() => generateTree(temp.path), throwsStateError);
  });

  test('celular simulado: JSON válido com conteúdo compartilhado com o HD', () {
    final demo = generatePhoneDemo(temp.path);
    final pixel = jsonDecode(File(demo.pixelJson).readAsStringSync()) as Map<String, Object?>;
    expect(pixel['kind'], 'android');
    final storages = pixel['storages']! as List<Object?>;
    expect(storages, hasLength(2));
    final first = (storages.first! as Map)['files'] as List<Object?>;
    final blob = File(p.join(demo.devicesDir, (first.first! as Map)['contentFile'] as String));
    final onHd = File(p.join(demo.hdDir, 'Backup do celular', '2024', '2024-05', 'foto praia.jpg'));
    expect(blob.readAsBytesSync(), onHd.readAsBytesSync());
    expect(File(p.join(demo.devicesDir, 'iphone.json')).existsSync(), isTrue);
  });

  test('mídia com metadados: JPEG com EXIF depois do SOI, MP4 com ftyp/moov, determinísticos', () {
    final spec = ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 14, 3, 12), make: 'Canon', offset: '-03:00');
    final jpeg = jpegWithExif(spec);
    expect(jpeg.sublist(0, 4), [0xFF, 0xD8, 0xFF, 0xE1]);
    expect(ascii.decode(jpeg.sublist(6, 10)), 'Exif');
    expect(jpeg, jpegWithExif(spec), reason: 'determinístico');
    expect(jpegWithExif(const ExifSpec(uniqueId: 'a')), isNot(jpegWithExif(const ExifSpec(uniqueId: 'b'))));
    final mp4 = mp4WithCreationTime(DateTime.utc(2024, 5, 1));
    expect(ascii.decode(mp4.sublist(4, 8)), 'ftyp');
    expect(mp4, isNot(mp4WithCreationTime(DateTime.utc(2024, 5, 1), salt: 1)));
  });

  test('HD bagunçado (reorganização): fotos, acompanhante, nota e Thumbs.db oculto', () {
    final out = p.join(temp.path, 'hd');
    final r = Process.runSync(Platform.resolvedExecutable, ['run', 'bin/gen_reorg_demo.dart', '--out', out]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    final files = {
      for (final f in Directory(out).listSync(recursive: true).whereType<File>())
        p.relative(f.path, from: out).replaceAll(r'\', '/'),
    };
    expect(files, hasLength(13));
    expect(files, contains('Downloads antigos/IMG_20240713_140300.xmp'));
    expect(files, contains('2024/2024-08-20 09h30/IMG_20240820_093000.jpg'));
    final attrib = Process.runSync('attrib', [p.join(out, 'Velhas', 'Thumbs.db')]).stdout as String;
    expect(attrib.substring(0, 12), allOf(contains('S'), contains('H')), reason: 'oculto e de sistema');
  });
}
