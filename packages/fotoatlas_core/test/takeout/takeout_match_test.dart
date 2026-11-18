import 'package:fotoatlas_core/src/takeout/takeout_match.dart';
import 'package:test/test.dart';

TakeoutSidecar j(String file, {String? title, int ts = 1700000000}) => TakeoutSidecar.parse(
  file,
  '{"title": ${title == null ? 'null' : '"$title"'}, "photoTakenTime": {"timestamp": "$ts"}, '
  '"geoData": {"latitude": -23.5, "longitude": -46.6}}',
)!;

void main() {
  test('lê data (UTC) e local; (0, 0) não é local; JSON que não é do Takeout fica de fora', () {
    final a = j('IMG_1.JPG.json', title: 'IMG_1.JPG');
    expect(a.takenUtcMs, 1700000000000);
    expect((a.lat, a.lon), (-23.5, -46.6));
    final b = TakeoutSidecar.parse(
      'x.json',
      '{"title": "x.jpg", "photoTakenTime": {"timestamp": "1700000000"}, "geoData": {"latitude": 0.0, "longitude": 0.0}}',
    )!;
    expect(b.lat, isNull);
    expect(TakeoutSidecar.parse('metadata.json', '{"albumData": {}}'), isNull);
    expect(TakeoutSidecar.parse('quebrado.json', '{'), isNull);
    expect(
      TakeoutSidecar.parse('x.json', '{"title": "x.jpg", "photoTakenTime": {"timestamp": "0"}}')!.takenUtcMs,
      isNull,
    );
  });

  test('nomes do Takeout: simples, supplemental, cortado, (1), editado e pelo título', () {
    final long = 'Screenshot_20240101-101010_Uma Conversa Longa.jpg';
    final jsons = [
      j('IMG_1.JPG.json', title: 'IMG_1.JPG', ts: 1700000001),
      j('IMG_2.HEIC.supplemental-metadata.json', title: 'IMG_2.HEIC', ts: 1700000002),
      j('IMG_2.HEIC.supplemental-metadata(1).json', title: 'IMG_2.HEIC', ts: 1700000003),
      // 46 caracteres antes do ".json".
      j('${'$long.supplemental-metadata'.substring(0, 46)}.json', title: long, ts: 1700000004),
      j('IMG_3.MP4.supplemental-me.json', title: 'IMG_3.MP4', ts: 1700000005),
      j('outro_nome.json', title: 'foto antiga.jpg', ts: 1700000006),
    ];
    final m = matchTakeout([
      'IMG_1.JPG',
      'IMG_1-editado.JPG',
      'IMG_2.HEIC',
      'IMG_2(1).HEIC',
      long,
      'IMG_3.MP4',
      'foto antiga.jpg',
      'sem_json.jpg',
    ], jsons);
    int? ts(String name) => m[name]?.takenUtcMs == null ? null : m[name]!.takenUtcMs! ~/ 1000;
    expect(ts('IMG_1.JPG'), 1700000001);
    expect(ts('IMG_1-editado.JPG'), 1700000001, reason: 'a editada usa o da original');
    expect(ts('IMG_2.HEIC'), 1700000002);
    expect(ts('IMG_2(1).HEIC'), 1700000003);
    expect(ts(long), 1700000004);
    expect(ts('IMG_3.MP4'), 1700000005);
    expect(ts('foto antiga.jpg'), 1700000006);
    expect(m.containsKey('sem_json.jpg'), isFalse);
  });
}
