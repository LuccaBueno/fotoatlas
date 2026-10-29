import 'package:fotoatlas_core/src/metadata/capture_date.dart';
import 'package:test/test.dart';

void main() {
  group('data no nome do arquivo', () {
    String? local(String name) {
      final c = filenameDate(name);
      return c?.wall == null ? null : formatWall(c!.wall!);
    }

    test('padrões de celular e câmera', () {
      expect(local('IMG_20190312_101112.jpg'), '2019-03-12T10:11:12');
      expect(local('VID_20190312_101112.mp4'), '2019-03-12T10:11:12');
      expect(local('IMG_20190312_101112_HDR.jpg'), '2019-03-12T10:11:12');
      expect(local('20240501_123456.jpg'), '2024-05-01T12:34:56', reason: 'Samsung');
      expect(local('20240501_123456(1).jpg'), '2024-05-01T12:34:56');
      expect(local('Screenshot_20240505-180000.png'), '2024-05-05T18:00:00');
      expect(local('Screenshot_2024-05-05-18-00-00-123_com.app.png'), '2024-05-05T18:00:00');
      expect(local('2019-03-12 10.11.12.jpg'), '2019-03-12T10:11:12', reason: 'Dropbox');
      expect(local('signal-2024-01-02-030405.jpg'), '2024-01-02T03:04:05');
    });

    test('WhatsApp: só o dia', () {
      final c = filenameDate('IMG-20190312-WA0001.jpg')!;
      expect(c.dayOnly, isTrue);
      expect(formatWall(c.wall!), '2019-03-12T00:00:00');
      expect(filenameDate('VID-20200101-WA0123.mp4')!.dayOnly, isTrue);
    });

    test('Pixel (PXL_) é UTC, com milissegundos', () {
      final c = filenameDate('PXL_20240501_170501123.jpg')!;
      expect(c.wall, isNull);
      expect(DateTime.fromMillisecondsSinceEpoch(c.utcMs!, isUtc: true), DateTime.utc(2024, 5, 1, 17, 5, 1, 123));
    });

    test('nomes sem data ou com data impossível não viram data', () {
      expect(filenameDate('DSC_1234.jpg'), isNull);
      expect(filenameDate('IMG_20191332_101112.jpg'), isNull, reason: 'mês 13');
      expect(filenameDate('IMG_20190230_101112.jpg'), isNull, reason: '30 de fevereiro');
      expect(filenameDate('IMG_20190312_256000.jpg'), isNull, reason: 'hora 25');
      expect(filenameDate('foto da praia.jpg'), isNull);
      expect(filenameDate('18001231_101112.jpg'), isNull, reason: 'ano fora da faixa');
    });
  });

  group('datas do EXIF', () {
    test('com subsegundos e fuso', () {
      final d = parseExifDate('2024:05:01 14:03:12', subSec: '045', offset: '-03:00')!;
      expect(formatWall(d.wall), '2024-05-01T14:03:12.045');
      expect(d.offsetMin, -180);
      expect(parseExifDate('2024:05:01 14:03:12.5+02:00')!.offsetMin, 120);
      expect(parseExifDate('2024:05:01 14:03:12.5+02:00')!.wall.millisecond, 500);
      expect(parseExifDate('2024:05:01 14:03:12Z')!.offsetMin, 0);
    });

    test('data zerada ou lixo → nada', () {
      expect(parseExifDate('0000:00:00 00:00:00'), isNull);
      expect(parseExifDate('    '), isNull);
      expect(parseExifDate(null), isNull);
    });
  });

  group('estratégia de data', () {
    const s = DateStrategy();
    DateTime utc(ResolvedDate r) => DateTime.fromMillisecondsSinceEpoch(r.utcMs, isUtc: true);

    test('EXIF com fuso → alta; o instante respeita o fuso do arquivo', () {
      final r = s.resolve([
        DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 14, 3, 12), offsetMin: 120),
      ])!;
      expect(r.confidence, DateConfidence.high);
      expect(utc(r), DateTime.utc(2024, 5, 1, 12, 3, 12));
      expect(formatWall(r.wall), '2024-05-01T14:03:12', reason: 'a tela mostra a hora vivida');
      expect(r.offsetMin, 120);
    });

    test('EXIF sem fuso → média, no fuso padrão (com o antigo horário de verão)', () {
      final r = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2018, 12, 1, 10))])!;
      expect(r.confidence, DateConfidence.medium);
      expect(r.offsetMin, -120, reason: 'São Paulo tinha horário de verão em 2018');
      expect(utc(r), DateTime.utc(2018, 12, 1, 12));
      final r2 = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 12, 1, 10))])!;
      expect(r2.offsetMin, -180);
    });

    test('vídeo em UTC → alta, convertido para a hora local', () {
      final r = s.resolve([
        DateCandidate(
          source: DateSource.videoInternal,
          utcMs: DateTime.utc(2024, 5, 1, 17, 5, 1).millisecondsSinceEpoch,
        ),
      ])!;
      expect(r.confidence, DateConfidence.high);
      expect(formatWall(r.wall), '2024-05-01T14:05:01');
    });

    test('foto (sem fuso) e vídeo (UTC) ficam na ordem certa', () {
      final foto = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 14, 3, 12))])!;
      final video = s.resolve([
        DateCandidate(
          source: DateSource.videoInternal,
          utcMs: DateTime.utc(2024, 5, 1, 17, 2, 50).millisecondsSinceEpoch,
        ),
      ])!;
      expect(video.utcMs, lessThan(foto.utcMs), reason: 'vídeo 14:02:50 local, foto 14:03:12');
    });

    test('prioridade: EXIF vence o nome; sem EXIF, o nome vence a data do arquivo', () {
      final fs = DateCandidate(source: DateSource.filesystem, utcMs: DateTime.utc(2025, 1, 1).millisecondsSinceEpoch);
      final nome = filenameDate('IMG_20240501_100000.jpg')!;
      final exif = DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 10, 0, 30));
      expect(s.resolve([fs, nome, exif])!.source, DateSource.exifOriginal);
      final r = s.resolve([fs, nome])!;
      expect(r.source, DateSource.filename);
      expect(r.confidence, DateConfidence.medium);
      final soArquivo = s.resolve([fs])!;
      expect(soArquivo.source, DateSource.filesystem);
      expect(soArquivo.confidence, DateConfidence.low);
    });

    test('prioridade configurável', () {
      const nomePrimeiro = DateStrategy(
        priority: [DateSource.filename, DateSource.exifOriginal, DateSource.filesystem],
      );
      final r = nomePrimeiro.resolve([
        DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 10)),
        filenameDate('IMG_20240501_100000.jpg')!,
      ])!;
      expect(r.source, DateSource.filename);
    });

    test('WhatsApp: hora pela data do arquivo se for o mesmo dia; senão meio-dia e hora incerta', () {
      final nome = filenameDate('IMG-20190312-WA0001.jpg')!;
      final mesmoDia = DateCandidate(
        source: DateSource.filesystem,
        utcMs: DateTime.utc(2019, 3, 12, 21, 30).millisecondsSinceEpoch, // 18:30 em SP
      );
      final r = s.resolve([nome, mesmoDia])!;
      expect(r.source, DateSource.filename);
      expect(r.confidence, DateConfidence.medium);
      expect(formatWall(r.wall), '2019-03-12T18:30:00');

      final outroDia = DateCandidate(
        source: DateSource.filesystem,
        utcMs: DateTime.utc(2023, 7, 1).millisecondsSinceEpoch,
      );
      final r2 = s.resolve([nome, outroDia])!;
      expect(r2.confidence, DateConfidence.low);
      expect(formatWall(r2.wall), '2019-03-12T12:00:00');
    });

    test('conflito: EXIF e nome discordam; a data do arquivo nunca conta como conflito', () {
      final exif = DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 10));
      expect(s.resolve([exif, filenameDate('IMG_20240501_100030.jpg')!])!.conflict, isFalse);
      expect(s.resolve([exif, filenameDate('IMG_20230101_100000.jpg')!])!.conflict, isTrue);
      const fs = DateCandidate(source: DateSource.filesystem, utcMs: 0);
      expect(s.resolve([exif, fs])!.conflict, isFalse);
      expect(s.resolve([exif, filenameDate('IMG-20240501-WA0001.jpg')!])!.conflict, isFalse);
      expect(s.resolve([exif, filenameDate('IMG-20240502-WA0001.jpg')!])!.conflict, isTrue);
    });

    test('candidatas vão e voltam do JSON', () {
      final c = [
        DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2024, 5, 1, 10, 0, 0, 45), offsetMin: -180),
        filenameDate('IMG-20190312-WA0001.jpg')!,
        const DateCandidate(source: DateSource.videoInternal, utcMs: 1714582800000),
      ];
      final back = DateStrategy.candidatesFromJson(DateStrategy.candidatesJson(c));
      expect(back.map((x) => x.toJson()), c.map((x) => x.toJson()));
    });
  });

  test('1º de janeiro à meia-noite em ponto parece relógio zerado: hora incerta', () {
    const s = DateStrategy();
    final zerado = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2023, 1, 1))])!;
    expect(zerado.confidence, DateConfidence.low);
    final umSegundo = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2023, 1, 1, 0, 0, 1))])!;
    expect(umSegundo.confidence, DateConfidence.medium);
    final outroDia = s.resolve([DateCandidate(source: DateSource.exifOriginal, wall: wallTime(2023, 1, 2))])!;
    expect(outroDia.confidence, DateConfidence.medium);
  });
}
