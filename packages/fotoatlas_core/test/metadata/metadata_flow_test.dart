import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/media_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';
import '../support/tools.dart';

/// Cenário da Fase 4: câmera (EXIF sem fuso), foto tirada na Europa (EXIF com
/// fuso), vídeo (data UTC), WhatsApp (só o dia no nome), arquivo sem data e
/// um celular (lido pelo começo do arquivo). Tudo sintético.
class _Scenario {
  _Scenario(this.env, this.devices, this.ids);
  final TestEnv env;
  final FakeDeviceBackend devices;

  /// nome do arquivo → content_id.
  final Map<String, int> ids;
  late final Map<String, List<int>> localBytes;

  FotoAtlasCore get core => env.core;

  static Future<_Scenario> build() async {
    final devices = FakeDeviceBackend();
    final phone = FakePhone();
    phone.put(
      'Interno/DCIM/Camera/20240501_100000.jpg',
      jpegWithExif(
        ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 10), make: 'samsung', model: 'SM-M546B', uniqueId: 'p1'),
      ),
    );
    phone.put(
      'Interno/DCIM/Camera/20240501_140250.jpg',
      jpegWithExif(
        ExifSpec(
          dateTimeOriginal: DateTime(2024, 5, 1, 14, 2, 50),
          make: 'samsung',
          model: 'SM-M546B',
          uniqueId: 'p2',
          color: 2,
        ),
      ),
    );
    devices.phones.add(phone);
    final env = await TestEnv.open(devices: devices);

    final cam = await env.addFolder('Camera', name: 'Câmera');
    void put(String name, List<int> bytes, {DateTime? mtime}) {
      final f = env.write('Camera/$name', bytes);
      if (mtime != null) f.setLastModifiedSync(mtime);
    }

    const canon = ('Canon', 'Canon EOS X', '0123');
    put(
      'canon_1.jpg',
      jpegWithExif(
        ExifSpec(
          dateTimeOriginal: DateTime(2024, 5, 1, 14, 3, 12),
          subSecMs: 450,
          make: canon.$1,
          model: canon.$2,
          serial: canon.$3,
          uniqueId: 'c1',
        ),
      ),
    );
    put(
      'canon_2.jpg',
      jpegWithExif(
        ExifSpec(
          dateTimeOriginal: DateTime(2024, 5, 1, 16, 45),
          make: canon.$1,
          model: canon.$2,
          serial: canon.$3,
          uniqueId: 'c2',
          color: 1,
        ),
      ),
    );
    // Tirada às 19:04 em Paris (+02:00) = 14:04 em São Paulo.
    put(
      'europa.jpg',
      jpegWithExif(
        ExifSpec(
          dateTimeOriginal: DateTime(2024, 5, 1, 19, 4),
          offset: '+02:00',
          make: 'samsung',
          model: 'SM-M546B',
          uniqueId: 'eu',
          lat: 48.85,
          lon: 2.35,
        ),
      ),
    );
    put('video.mp4', mp4WithCreationTime(DateTime.utc(2024, 5, 1, 17, 5, 30)));
    put('IMG-20240501-WA0001.jpg', baseJpeg(2), mtime: DateTime.utc(2024, 5, 1, 20, 30)); // 17:30 em SP
    put('semdata.jpg', baseJpeg(3), mtime: DateTime.utc(2023, 1, 1, 6)); // 03:00 em SP

    final phoneId = (await env.core.sources.addPhone(phone.deviceId)).sourceId;
    await env.scan(cam);
    await env.scan(phoneId);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();

    final rows = await env.db
        .customSelect('SELECT name, content_id FROM file_instances WHERE content_id IS NOT NULL')
        .get();
    final s = _Scenario(env, devices, {for (final r in rows) r.read<String>('name'): r.read<int>('content_id')});
    s.localBytes = {
      for (final f in Directory(p.join(env.volumeDir.path, 'Camera')).listSync().whereType<File>())
        f.path: f.readAsBytesSync(),
    };
    return s;
  }

  Future<List<String>> timeline(LibraryFilter filter, {bool ascending = true}) async {
    final index = await core.library.index(filter, ascending: ascending);
    final byId = {for (final e in ids.entries) e.value: e.key};
    return [for (final id in index.ids) byId[id]!];
  }

  Future<int> count(LibraryFilter f) => core.library.count(f);

  Future<Map<String, Object?>> meta(String name) async =>
      (await env.db.customSelect('SELECT * FROM media_metadata WHERE content_id = ${ids[name]}').getSingle()).data;

  void expectSourcesUntouched() {
    for (final e in localBytes.entries) {
      expect(sha256.convert(File(e.key).readAsBytesSync()), sha256.convert(e.value), reason: e.key);
    }
  }
}

void main() {
  final tools = ExternalTools.locate();

  group('metadados e linha do tempo', () {
    test('datas, fusos, WhatsApp, celular e ordem real entre dispositivos', () async {
      final s = await _Scenario.build();
      expect(await s.timeline(LibraryFilter.empty), [
        'semdata.jpg', // 2023, hora incerta
        '20240501_100000.jpg', // celular 10:00
        '20240501_140250.jpg', // celular 14:02:50
        'canon_1.jpg', // câmera 14:03:12.450
        'europa.jpg', // 19:04 em Paris = 14:04 aqui
        'video.mp4', // 17:05:30 UTC = 14:05:30
        'canon_2.jpg', // 16:45
        'IMG-20240501-WA0001.jpg', // WhatsApp: dia do nome + hora do arquivo (17:30)
      ]);

      final c1 = await s.meta('canon_1.jpg');
      expect(c1['eff_local'], '2024-05-01T14:03:12.450');
      expect(c1['eff_confidence'], 'medium', reason: 'EXIF sem fuso');
      expect(c1['eff_offset_min'], -180);
      expect((c1['make'], c1['model'], c1['body_serial']), ('Canon', 'Canon EOS X', '0123'));
      expect(c1['meta_status'], 'full');

      final eu = await s.meta('europa.jpg');
      expect((eu['eff_local'], eu['eff_offset_min'], eu['eff_confidence']), ('2024-05-01T19:04:00', 120, 'high'));
      expect(eu['lat'], closeTo(48.85, 1e-6));

      final v = await s.meta('video.mp4');
      expect(
        (v['eff_local'], v['eff_confidence'], v['date_source']),
        ('2024-05-01T14:05:30', 'high', 'video_internal'),
      );

      final wa = await s.meta('IMG-20240501-WA0001.jpg');
      expect((wa['eff_local'], wa['eff_confidence'], wa['date_source']), ('2024-05-01T17:30:00', 'medium', 'filename'));

      final none = await s.meta('semdata.jpg');
      expect((none['eff_confidence'], none['date_source']), ('low', 'filesystem'));

      // Celular: lido só o começo do arquivo, sem sobrar nada no cache.
      final ph = await s.meta('20240501_140250.jpg');
      expect((ph['make'], ph['eff_local'], ph['meta_status']), ('samsung', '2024-05-01T14:02:50', 'full'));
      expect(s.devices.readHeadCalls, greaterThanOrEqualTo(2));
      final leftovers = Directory(p.join(s.core.paths.thumbsDir, '_leitura'));
      expect(leftovers.existsSync() ? leftovers.listSync() : const [], isEmpty);

      // Momentos (intervalo padrão de 2 h): manhã | 14:02–14:05 | 16:45–17:30; hora incerta fora.
      final moments = await s.core.moments.list();
      expect([for (final m in moments) m.itemCount], [1, 4, 2]);
      expect(none['moment_id'], isNull);
      expect(moments[1].startLocal, wallTime(2024, 5, 1, 14, 2, 50));

      // Miniaturas: EXIF embutido (arquivo local e celular); vídeo sem quadro → sem miniatura.
      final t1 = await s.core.thumbnails.thumbnail(s.ids['canon_1.jpg']!);
      expect(t1, isNotNull);
      expect(File(t1!).readAsBytesSync().sublist(0, 2), [0xFF, 0xD8]);
      expect(p.isWithin(s.core.paths.thumbsDir, t1), isTrue);
      expect(await s.core.thumbnails.thumbnail(s.ids['20240501_140250.jpg']!), isNotNull);

      s.expectSourcesUntouched();
    });

    test('momentos: nomear, juntar e separar sobrevivem a recálculos; hora incerta entra ao confirmar', () async {
      final s = await _Scenario.build();
      final m = s.core.moments;
      var list = await m.list();
      final tarde = list[1];
      await m.rename(tarde.id, 'Aniversário da Ana');

      // Intervalo de 1 min: os automáticos se quebram; o nomeado fica igual.
      await m.setGap(const Duration(minutes: 1));
      list = await m.list();
      final named = list.singleWhere((x) => x.name == 'Aniversário da Ana');
      expect(named.id, tarde.id);
      expect(named.itemCount, 4);
      expect(list.length, 4, reason: 'manhã | aniversário | 16:45 | 17:30');

      await m.setGap(MomentsService.defaultGap);
      list = await m.list();
      expect([for (final x in list) x.itemCount], [1, 4, 2]);

      // Juntar manhã + aniversário (vizinhos): fica com o nome do aniversário.
      final merged = await m.merge([list[0].id, list[1].id]);
      list = await m.list();
      expect(list.length, 2);
      expect((list[0].id, list[0].name, list[0].itemCount), (merged, 'Aniversário da Ana', 5));
      // Não dá para juntar quem não é vizinho.
      await m.split(merged, s.ids['canon_1.jpg']!);
      list = await m.list();
      expect([for (final x in list) x.itemCount], [2, 3, 2]);
      expect(list[1].edited, isTrue);
      await expectLater(m.merge([list[0].id, list[2].id]), throwsStateError);

      // Recalcular (novas fotos, outro intervalo) não desfaz as edições.
      await m.setGap(const Duration(hours: 5));
      list = await m.list();
      expect([for (final x in list) x.itemCount], [2, 3, 2]);
      final edits = await s.env.count('SELECT COUNT(*) FROM moment_edits');
      expect(edits, 3);

      // Voltar ao automático.
      await m.reset(list[1].id);
      await m.reset(list[0].id);
      await m.setGap(MomentsService.defaultGap);
      expect([for (final x in await m.list()) x.itemCount], [1, 4, 2]);

      // Hora a confirmar: fora dos momentos até confirmar.
      const toConfirm = LibraryFilter([FilterCondition(FilterKind.toConfirm)]);
      expect(await s.timeline(toConfirm), ['semdata.jpg']);
      await s.core.dates.confirm([s.ids['semdata.jpg']!]);
      expect(await s.count(toConfirm), 0);
      expect((await s.meta('semdata.jpg'))['moment_id'], isNotNull);
      expect([for (final x in await m.list()) x.itemCount], [1, 1, 4, 2]);

      // Nada disso tocou nos arquivos.
      s.expectSourcesUntouched();
    });

    test('correção de relógio da câmera: prévia, aplicar só no catálogo e desfazer', () async {
      final s = await _Scenario.build();
      final d = s.core.dates;
      final devices = await d.captureDevices();
      expect(devices.map((x) => x.label), containsAll(['Canon EOS X (nº 0123)', 'samsung SM-M546B']));

      // A câmera estava 1 h adiantada.
      const draft = ClockCorrectionDraft(
        make: 'Canon',
        model: 'Canon EOS X',
        serial: '0123',
        offset: Duration(hours: -1),
      );
      final preview = await d.preview(draft);
      expect(preview.affected, 2);
      final ex = preview.examples.firstWhere((e) => e.name == 'canon_1.jpg');
      expect((ex.before, ex.after), (wallTime(2024, 5, 1, 14, 3, 12, 450), wallTime(2024, 5, 1, 13, 3, 12, 450)));
      expect(ex.neighborName, isNotNull);
      // A prévia não grava nada.
      expect((await s.meta('canon_1.jpg'))['eff_local'], '2024-05-01T14:03:12.450');
      expect(await s.env.count('SELECT COUNT(*) FROM clock_corrections'), 0);

      final id = await d.applyCorrection(draft);
      expect((await s.meta('canon_1.jpg'))['eff_local'], '2024-05-01T13:03:12.450');
      expect((await s.meta('canon_1.jpg'))['capture_local'], '2024-05-01T14:03:12.450', reason: 'a data extraída fica');
      expect((await s.meta('canon_2.jpg'))['clock_correction_id'], id);
      expect((await s.meta('europa.jpg'))['clock_correction_id'], isNull, reason: 'outro dispositivo');
      const corrected = LibraryFilter([FilterCondition(FilterKind.corrected)]);
      expect(await s.count(corrected), 2);
      s.expectSourcesUntouched();

      // Alinhar com o celular: deslocamento entre a foto da câmera e a do celular.
      final offset = await d.offsetBetween(s.ids['canon_1.jpg']!, s.ids['20240501_140250.jpg']!);
      expect(offset, const Duration(seconds: -22, milliseconds: -450));

      await d.undoCorrection(id);
      expect((await s.meta('canon_1.jpg'))['eff_local'], '2024-05-01T14:03:12.450');
      expect(await s.count(corrected), 0);
      expect((await d.corrections()).single.undoneAt, isNotNull, reason: 'fica no histórico');

      // Hora manual vale acima de tudo e pode ser tirada.
      await d.setManual([s.ids['video.mp4']!], wallTime(2024, 5, 1, 9));
      expect((await s.meta('video.mp4'))['eff_source'], 'manual');
      await d.clearManual([s.ids['video.mp4']!]);
      expect((await s.meta('video.mp4'))['eff_local'], '2024-05-01T14:05:30');
    });

    test('filtros de data, horário, período, dia da semana, momento, câmera, fonte, texto e backup', () async {
      final s = await _Scenario.build();
      Future<int> n(List<FilterCondition> c, {bool any = false}) => s.count(LibraryFilter(c, any));
      expect(await n([]), 8);
      expect(
        await n([
          const FilterCondition(FilterKind.years, values: [2024]),
        ]),
        7,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.years, values: [2024], negate: true),
        ]),
        1,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.months, values: ['2024-05']),
        ]),
        7,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.dateRange, values: ['2024-05-01', '2024-05-01']),
        ]),
        7,
      );
      // 14:00–14:10 pela hora local: Paris (19:04 lá) não entra.
      expect(await n([const FilterCondition(FilterKind.timeRange, min: 14 * 60, max: 14 * 60 + 10)]), 3);
      // 22:00–04:00 atravessa a meia-noite.
      expect(await n([const FilterCondition(FilterKind.timeRange, min: 22 * 60, max: 4 * 60)]), 1);
      expect(
        await n([
          FilterCondition(FilterKind.periods, values: [DayPart.tarde.name]),
        ]),
        5,
      );
      expect(
        await n([
          FilterCondition(FilterKind.periods, values: [DayPart.noite.name]),
        ]),
        1,
      );
      expect(
        await n([
          FilterCondition(FilterKind.periods, values: [DayPart.madrugada.name, DayPart.manha.name]),
        ]),
        2,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.weekdays, values: [3]),
        ]),
        7,
        reason: '1º/5/2024 foi quarta',
      );
      expect(
        await n([
          const FilterCondition(FilterKind.weekdays, values: [7]),
        ]),
        1,
        reason: '1º/1/2023 foi domingo',
      );
      final moments = await s.core.moments.list();
      expect(
        await n([
          FilterCondition(FilterKind.moments, values: [moments[1].id]),
        ]),
        4,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.confidence, values: ['high']),
        ]),
        2,
      );
      expect(await n([const FilterCondition(FilterKind.toConfirm)]), 1);
      expect(
        await n([
          const FilterCondition(FilterKind.cameras, values: ['Canon\u0001Canon EOS X']),
        ]),
        2,
      );
      final phoneId = (await s.core.sources.list()).singleWhere((x) => x.kind == 'phone').id;
      expect(
        await n([
          FilterCondition(FilterKind.sources, values: [phoneId]),
        ]),
        2,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.types, values: ['video']),
        ]),
        1,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.gps, values: [true]),
        ]),
        1,
      );
      expect(await n([const FilterCondition(FilterKind.text, text: 'WA0001')]), 1);
      expect(
        await n([
          const FilterCondition(FilterKind.backup, values: ['single']),
        ]),
        8,
      );
      expect(
        await n([
          const FilterCondition(FilterKind.backup, values: ['verified', 'independent']),
        ]),
        0,
      );
      // OU e NÃO.
      expect(
        await n(any: true, [
          const FilterCondition(FilterKind.years, values: [2023]),
          const FilterCondition(FilterKind.cameras, values: ['Canon\u0001Canon EOS X']),
        ]),
        3,
      );

      // Filtro salvo.
      const f = LibraryFilter([
        FilterCondition(FilterKind.periods, values: ['tarde']),
        FilterCondition(FilterKind.types, values: ['video'], negate: true),
      ]);
      await s.core.library.saveFilter('Tardes sem vídeo', f);
      final saved = (await s.core.library.savedFilters()).single;
      expect(saved.name, 'Tardes sem vídeo');
      expect(await s.count(saved.filter), 4);

      // Seleção: tamanho e situação de backup.
      final sum = await s.core.library.summarize(s.ids.values);
      expect(sum.items, 8);
      expect(sum.files, 8);
      expect(sum.backup[BackupState.single], 8);
      final facets = await s.core.library.facets();
      expect((facets.total, facets.years[2024], facets.toConfirm), (8, 7, 1));
    });

    test('momento como escopo na Comparar (em todos os dispositivos ou só numa fonte) e filtro no escopo', () async {
      final s = await _Scenario.build();
      final sources = await s.core.sources.list();
      final phone = sources.singleWhere((x) => x.kind == 'phone').id;
      final cam = sources.singleWhere((x) => x.kind != 'phone').id;
      final tarde = (await s.core.moments.list())[1];
      final b = Scope([ScopeEntry(phone)]);
      var r = await s.core.compare.compare(Scope(const [], moments: [MomentScopeEntry(tarde.id)]), b);
      expect((r.aContents, r.missing.contents, r.inBoth.contents), (4, 3, 1));
      r = await s.core.compare.compare(Scope(const [], moments: [MomentScopeEntry(tarde.id, cam)]), b);
      expect((r.aContents, r.missing.contents), (3, 3), reason: 'só a parte da câmera');
      final canon = Scope(
        [ScopeEntry(cam)],
        filter: const LibraryFilter([
          FilterCondition(FilterKind.cameras, values: ['Canon\u0001Canon EOS X']),
        ]),
      );
      r = await s.core.compare.compare(canon, b);
      expect((r.aContents, r.missing.contents), (2, 2));

      // Salvo com nome: momento e filtro voltam iguais (v: 2); o formato antigo continua lendo.
      final back = Scope.fromJson(
        Scope(const [], moments: [MomentScopeEntry(tarde.id, cam)], filter: canon.filter).toJson(),
      );
      expect(back.moments, [MomentScopeEntry(tarde.id, cam)]);
      expect(back.filter!.conditions, canon.filter!.conditions);
      expect(Scope.fromJson('{"v":1,"entries":[{"source":"x","path":"a"}]}').entries.single.relPath, 'a');
      expect(jsonDecode(Scope([ScopeEntry(cam)]).toJson())['v'], 1);
    });

    test('mudar o fuso padrão recalcula sem ler os arquivos de novo', () async {
      final s = await _Scenario.build();
      final readsBefore = s.devices.readHeadCalls;
      await s.core.metadata.setZone('Europe/Lisbon');
      await s.core.settleDates();
      final c1 = await s.meta('canon_1.jpg');
      expect((c1['eff_local'], c1['eff_offset_min']), ('2024-05-01T14:03:12.450', 60));
      expect(s.devices.readHeadCalls, readsBefore);
      final eu = await s.meta('europa.jpg');
      expect(eu['eff_offset_min'], 120, reason: 'quem tem fuso no arquivo não muda');
    });
  }, skip: skipWithoutTool(tools.exiftool, 'ExifTool'));

  test('sem ExifTool: datas do nome e do arquivo, completadas quando a ferramenta existir', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final src = await env.addFolder('F');
    env.write('F/IMG_20240501_101112.jpg', jpegWithExif(ExifSpec(dateTimeOriginal: DateTime(2020, 1, 1))));
    await env.scan(src);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final row = await env.db.customSelect('SELECT eff_local, meta_status, date_source FROM media_metadata').getSingle();
    expect(row.read<String>('eff_local'), '2024-05-01T10:11:12');
    expect(row.read<String>('date_source'), 'filename');
    expect(row.read<String>('meta_status'), 'partial');
    expect(env.core.metadata.current.exifToolMissing, isTrue);
  });
}
