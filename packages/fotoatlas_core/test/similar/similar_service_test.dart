import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';

List<int> photo(int seed, [SceneVariant v = SceneVariant.original]) => jpegWithExif(
  ExifSpec(dateTimeOriginal: DateTime(2024, 5, seed, 10), make: 'Teste', model: 'Cena', thumbnail: false),
  image: sceneJpeg(seed, v),
);

/// Foto → SHA-256 e data de modificação, para provar que nada foi tocado.
Map<String, (String, DateTime)> snapshot(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    f.path: (sha256.convert(f.readAsBytesSync()).toString(), f.lastModifiedSync()),
};

Future<int> contentOf(TestEnv env, String name) async =>
    (await env.db
            .customSelect('SELECT content_id FROM file_instances WHERE name = ? LIMIT 1', variables: [Variable(name)])
            .getSingle())
        .read<int>('content_id');

void main() {
  group('fotos parecidas', () {
    late TestEnv env;
    late Map<String, int> ids;
    late Map<String, (String, DateTime)> before;

    setUp(() async {
      env = await TestEnv.open();
      final files = {
        'praia.jpg': photo(1),
        'praia_whatsapp.jpg': photo(1, SceneVariant.half),
        'praia_baixa.jpg': photo(1, SceneVariant.lowQuality),
        'rajada_1.jpg': photo(2),
        'rajada_2.jpg': photo(2, SceneVariant.burst),
        'sozinha.jpg': photo(3),
        'tela_preta.jpg': flatJpeg(4, 4, 4),
      };
      for (final MapEntry(:key, :value) in files.entries) {
        env.write('Fotos/$key', value);
      }
      // Cópia idêntica: é o mesmo conteúdo, não uma "parecida".
      env.write('Fotos/backup/praia.jpg', files['praia.jpg']!);
      final source = await env.addFolder('Fotos');
      await env.scan(source);
      await env.hashAll();
      before = snapshot(Directory(p.join(env.volumeDir.path, 'Fotos')));
      ids = {for (final name in files.keys) name: await contentOf(env, name)};
    });

    test('calcula as impressões e sugere grupos com nível de confiança, sem tocar em nada', () async {
      final similar = env.core.similar;
      await similar.start();
      expect(similar.current.running, isFalse);
      expect(await env.count('SELECT COUNT(*) FROM visual_hashes'), 7, reason: 'cópia idêntica conta uma vez');
      expect(await env.count('SELECT COUNT(*) FROM visual_hashes WHERE flat = 1'), 1);
      final overview = await similar.overview();
      expect(overview.photos, 7);
      expect(overview.analyzed, 7);

      final groups = await similar.groups();
      final sets = [for (final g in groups) g.contentIds.toSet()];
      expect(sets, hasGroup({ids['praia.jpg'], ids['praia_whatsapp.jpg'], ids['praia_baixa.jpg']}));
      expect(sets, hasGroup({ids['rajada_1.jpg'], ids['rajada_2.jpg']}));
      expect(sets.expand((s) => s), isNot(contains(ids['sozinha.jpg'])));
      expect(sets.expand((s) => s), isNot(contains(ids['tela_preta.jpg'])));
      final praia = groups.firstWhere((g) => g.contentIds.contains(ids['praia.jpg']));
      expect(praia.level, SimilarLevel.nearIdentical);

      // Só "quase idênticas": a rajada (mais fraca) pode sair, a praia fica.
      final strong = await similar.groups(minLevel: SimilarLevel.nearIdentical);
      expect([for (final g in strong) g.contentIds.toSet()], hasGroup(praia.contentIds));

      // Nada foi tocado; as miniaturas ficam só no cache.
      expect(snapshot(Directory(p.join(env.volumeDir.path, 'Fotos'))), before);
      final thumbs = Directory(env.core.paths.thumbsDir).listSync(recursive: true).whereType<File>();
      expect(thumbs, isNotEmpty);
      expect(thumbs.every((f) => p.isWithin(env.core.paths.thumbsDir, f.path)), isTrue);

      // Rodar de novo não recalcula nada.
      final stamps = await env.db.customSelect('SELECT content_id, computed_at FROM visual_hashes ORDER BY 1').get();
      await similar.start();
      final again = await env.db.customSelect('SELECT content_id, computed_at FROM visual_hashes ORDER BY 1').get();
      expect([for (final r in again) r.data], [for (final r in stamps) r.data]);
    });

    test('"Não são parecidas" e "Tirar do grupo": só no catálogo, com Desfazer', () async {
      final similar = env.core.similar;
      await similar.start();
      final rajada = [ids['rajada_1.jpg']!, ids['rajada_2.jpg']!];
      final pairs = await similar.dismiss(rajada);
      expect(pairs, hasLength(1));
      var sets = [for (final g in await similar.groups()) g.contentIds.toSet()];
      expect(sets.any((s) => s.contains(rajada[0])), isFalse);
      expect((await similar.overview()).dismissedPairs, 1);

      await similar.undoDismiss(pairs);
      sets = [for (final g in await similar.groups()) g.contentIds.toSet()];
      expect(sets, hasGroup(rajada.toSet()));

      // Tirar a recomprimida do grupo da praia: as outras duas continuam juntas.
      final praia = [ids['praia.jpg']!, ids['praia_whatsapp.jpg']!, ids['praia_baixa.jpg']!];
      await similar.dismissFrom(ids['praia_baixa.jpg']!, praia);
      sets = [for (final g in await similar.groups()) g.contentIds.toSet()];
      expect(sets, hasGroup({ids['praia.jpg'], ids['praia_whatsapp.jpg']}));
      expect(sets.expand((s) => s), isNot(contains(ids['praia_baixa.jpg'])));

      expect(await similar.restoreAllDismissed(), 2);
      sets = [for (final g in await similar.groups()) g.contentIds.toSet()];
      expect(sets, hasGroup(praia.toSet()));
      expect(snapshot(Directory(p.join(env.volumeDir.path, 'Fotos'))), before);
    });

    test('cede a vez: com outra tarefa em andamento, espera e não calcula nada', () async {
      final busy = SimilarService(env.db, env.core.sources, env.core.thumbnails, busy: () => true, useIsolate: false);
      addTearDown(busy.dispose);
      await busy.start();
      expect(busy.current.waiting, isTrue);
      expect(await env.count('SELECT COUNT(*) FROM visual_hashes'), 0);
      expect(Directory(env.core.paths.thumbsDir).existsSync(), isFalse, reason: 'nem miniatura foi gerada');
    });

    test('pausar para a fila e "Continuar" termina o que faltava', () async {
      final similar = env.core.similar;
      final run = similar.start();
      await similar.pause();
      await run;
      expect(similar.current.paused, isTrue);
      await similar.start();
      expect(await env.count('SELECT COUNT(*) FROM visual_hashes'), 7);
    });
  });

  test('nunca lê do celular para calcular a impressão', () async {
    final phone = FakePhone()
      ..put('Interno/DCIM/Camera/IMG_0001.jpg', photo(5))
      ..put('Interno/DCIM/Camera/IMG_0002.jpg', photo(5, SceneVariant.half));
    final devices = FakeDeviceBackend()..phones.add(phone);
    final env = await TestEnv.open(devices: devices);
    await env.core.sources.refreshConnectivity();
    final id = (await env.core.sources.addPhone(phone.deviceId)).sourceId;
    await env.scan(id);
    await env.hashAll();
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), 2);
    final readsBefore = devices.readHeadCalls;

    await env.core.similar.start();
    expect(devices.readHeadCalls, readsBefore, reason: 'nada lido do celular');
    expect(await env.count('SELECT COUNT(*) FROM visual_hashes'), 0);

    // A Biblioteca ainda pode gerar a miniatura pelo celular (a falha da fila não a bloqueia).
    final content = await contentOf(env, 'IMG_0001.jpg');
    expect(await env.core.thumbnails.thumbnail(content), isNull, reason: 'cena sem miniatura no EXIF');
    expect(devices.readHeadCalls, greaterThan(readsBefore));
  });
}

/// Algum grupo com exatamente estas fotos.
Matcher hasGroup(Iterable<int?> ids) => contains(equals(ids.toSet()));
