import 'dart:io';

import 'package:fotoatlas_core/src/metadata/capture_date.dart';
import 'package:fotoatlas_core/src/metadata/exiftool.dart';
import 'package:fotoatlas_core/src/metadata/external_tools.dart';
import 'package:fotoatlas_fixtures/media_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';
import '../support/tools.dart';

void main() {
  test('argumentos do ExifTool são só de leitura', () {
    for (final a in ExifTool.readArgs) {
      if (!a.startsWith('-')) continue; // valor de -charset/-api
      expect(a.contains('=') || a.contains('<'), isFalse, reason: '$a gravaria um tag');
      expect(ExifTool.forbiddenOptions.map((o) => o.toLowerCase()), isNot(contains(a.toLowerCase())));
    }
    expect(Ffprobe.args, isNot(contains('-y')));
  });

  final tools = ExternalTools.locate();
  group('ExifTool real', () {
    late Directory dir;
    late ExifTool exif;
    setUp(() async {
      dir = await createTestTemp();
      exif = ExifTool(tools.exiftool!);
    });
    tearDown(() => exif.close());

    test('lê data com subsegundos e fuso, câmera, série, GPS; vídeo em UTC; nome com acento', () async {
      final foto = p.join(dir.path, 'câmera ação.jpg');
      File(foto).writeAsBytesSync(
        jpegWithExif(
          ExifSpec(
            dateTimeOriginal: DateTime(2024, 5, 1, 14, 3, 12),
            subSecMs: 45,
            offset: '-03:00',
            make: 'Canon',
            model: 'Canon EOS X',
            serial: '0123',
            lat: -23.5,
            lon: -46.6,
          ),
        ),
      );
      final semFuso = p.join(dir.path, 'b.jpg');
      File(semFuso).writeAsBytesSync(jpegWithExif(ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 14, 2, 50))));
      final video = p.join(dir.path, 'c.mp4');
      File(video).writeAsBytesSync(mp4WithCreationTime(DateTime.utc(2024, 5, 1, 17, 5, 1), durationMs: 2500));
      final semExif = p.join(dir.path, 'IMG-20190312-WA0001.jpg');
      File(semExif).writeAsBytesSync(baseJpeg());
      final lixo = p.join(dir.path, 'quebrada.jpg');
      File(lixo).writeAsBytesSync(List.generate(500, (i) => i % 7));
      final sumiu = p.join(dir.path, 'nao-existe.jpg');

      final before = {
        for (final f in [foto, semFuso, video, semExif, lixo]) f: File(f).readAsBytesSync(),
      };
      final r = await exif.extract([foto, semFuso, video, semExif, lixo, sumiu]);
      expect(exif.name, startsWith('exiftool 13.'));

      final a = r[foto]!.metadata!;
      expect(formatWall(a.exifDate!.wall!), '2024-05-01T14:03:12.045');
      expect(a.exifDate!.offsetMin, -180);
      expect((a.make, a.model, a.serial), ('Canon', 'Canon EOS X', '0123'));
      expect(a.lat, closeTo(-23.5, 1e-6));
      expect(a.lon, closeTo(-46.6, 1e-6));
      expect((a.width, a.height), (32, 24));

      expect(r[semFuso]!.metadata!.exifDate!.offsetMin, isNull);

      final v = r[video]!.metadata!;
      expect(v.exifDate, isNull);
      expect(DateTime.fromMillisecondsSinceEpoch(v.videoDate!.utcMs!, isUtc: true), DateTime.utc(2024, 5, 1, 17, 5, 1));
      expect(v.durationMs, 2500);

      expect(r[semExif]!.metadata!.exifDate, isNull);
      expect(r[lixo]!.error, isNotNull);
      expect(r[sumiu]!.error, isNotNull);

      // Só leitura: nada mudou.
      for (final e in before.entries) {
        expect(File(e.key).readAsBytesSync(), e.value, reason: e.key);
      }
      expect(dir.listSync().map((f) => p.basename(f.path)).toSet(), {
        'câmera ação.jpg',
        'b.jpg',
        'c.mp4',
        'IMG-20190312-WA0001.jpg',
        'quebrada.jpg',
      }, reason: 'nenhum arquivo novo (ex.: _original)');
    });

    test('vários lotes no mesmo processo e reinício depois de fechar', () async {
      final f = p.join(dir.path, 'x.jpg');
      File(f).writeAsBytesSync(jpegWithExif(ExifSpec(dateTimeOriginal: DateTime(2020, 1, 2, 3, 4, 5))));
      for (var i = 0; i < 3; i++) {
        expect((await exif.extract([f]))[f]!.metadata!.exifDate, isNotNull);
      }
      await exif.close();
      expect((await exif.extract([f]))[f]!.metadata!.exifDate, isNotNull);
    });
  }, skip: skipWithoutTool(tools.exiftool, 'ExifTool'));

  group('ffprobe real', () {
    test('data UTC do vídeo; arquivo inválido volta com erro', () async {
      final dir = await createTestTemp();
      final video = p.join(dir.path, 'c.mp4');
      File(video).writeAsBytesSync(mp4WithCreationTime(DateTime.utc(2024, 5, 1, 17, 5, 1), durationMs: 2500));
      final probe = Ffprobe(tools.ffprobe!);
      final m = (await probe.probe(video)).metadata!;
      expect(DateTime.fromMillisecondsSinceEpoch(m.videoDate!.utcMs!, isUtc: true), DateTime.utc(2024, 5, 1, 17, 5, 1));
      final lixo = p.join(dir.path, 'x.mp4');
      File(lixo).writeAsBytesSync(List.filled(100, 1));
      expect((await probe.probe(lixo)).error, isNotNull);
    });
  }, skip: skipWithoutTool(tools.ffprobe, 'ffprobe'));
}
