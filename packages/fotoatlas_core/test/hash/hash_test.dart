import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_core/src/hash/hash_service.dart';
import 'package:fotoatlas_core/src/platform/win32/kernel32.dart';
import 'package:fotoatlas_core/src/safe_io/source_reader.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 31 + seed * 7) & 0xff);

Future<String> hashHexOf(TestEnv env, String sourceId, String relPath) async {
  final row = await env.db
      .customSelect(
        'SELECT hex(c.sha256) AS h FROM file_instances f JOIN contents c ON c.id = f.content_id '
        'WHERE f.source_id = ? AND f.rel_path = ?',
        variables: [Variable.withString(sourceId), Variable.withString(relPath)],
      )
      .getSingle();
  return row.read<String>('h').toLowerCase();
}

Future<String> statusOf(TestEnv env, String relPath) async =>
    (await env.db
            .customSelect(
              'SELECT hash_status FROM file_instances WHERE rel_path = ?',
              variables: [Variable.withString(relPath)],
            )
            .getSingle())
        .read<String>('hash_status');

void main() {
  for (final isolate in [false, true]) {
    test(
      'confere o conteúdo: SHA-256 correto, idênticos agrupados (${isolate ? 'em isolate' : 'mesmo isolate'})',
      () async {
        final env = await TestEnv.open(isolate: isolate);
        final same = bytes(1, 300000); // > 1 bloco de leitura
        env.write('Fotos/IMG_0001.jpg', same);
        env.write('Fotos/copia com outro nome.jpg', same);
        env.write('Fotos/sub/IMG_0002.jpg', bytes(2, 5000));
        env.write('Fotos/vazio.txt', const []);
        final id = await env.addFolder('Fotos');
        await env.scan(id);
        await env.hashAll();

        expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), 4);
        expect(await hashHexOf(env, id, 'IMG_0001.jpg'), sha256.convert(same).toString());
        expect(await hashHexOf(env, id, 'vazio.txt'), sha256.convert(const <int>[]).toString());
        // Conteúdo idêntico com nomes diferentes → um só conteúdo.
        expect(await env.count('SELECT COUNT(*) FROM contents'), 3);
        expect(
          await env.count(
            "SELECT COUNT(DISTINCT content_id) FROM file_instances WHERE name IN ('IMG_0001.jpg', 'copia com outro nome.jpg')",
          ),
          1,
        );
        expect(env.core.hashes.current.running, isFalse);
        expect(env.core.hashes.current.filesDone, 4);
      },
    );
  }

  test('mesmo nome com conteúdo diferente não é agrupado', () async {
    final env = await TestEnv.open();
    env.write('A/IMG_0001.jpg', bytes(1, 1000));
    env.write('B/IMG_0001.jpg', bytes(2, 1000));
    final a = await env.addFolder('A');
    final b = await env.addFolder('B');
    await env.scan(a);
    await env.scan(b);
    await env.hashAll();
    expect(await hashHexOf(env, a, 'IMG_0001.jpg'), isNot(await hashHexOf(env, b, 'IMG_0001.jpg')));
    expect(await env.count('SELECT COUNT(*) FROM contents'), 2);
  });

  group('arquivo alterado', () {
    Future<(TestEnv, HashService, File)> setup() async {
      final env = await TestEnv.open();
      final f = env.write('Fotos/video.mp4', bytes(3, 64 * 1024));
      final id = await env.addFolder('Fotos');
      await env.scan(id);
      final service = HashService(
        env.core.catalog,
        env.core.sources,
        env.core.scans,
        useIsolate: false,
        chunkSize: 4096,
      );
      addTearDown(service.dispose);
      return (env, service, f);
    }

    test('crescendo durante a leitura é detectado (tamanho)', () async {
      final (env, service, f) = await setup();
      service.debugAfterFirstChunk = (_) => f.writeAsBytesSync([1, 2, 3], mode: FileMode.append);
      await service.start();
      await service.waitIdle();
      expect(await statusOf(env, 'video.mp4'), 'changed_during_read');
      expect(await env.count('SELECT COUNT(*) FROM contents'), 0, reason: 'nada de conteúdo meio-lido');
      expect(service.current.changed, 1);
    });

    test('reescrito com o mesmo tamanho durante a leitura é detectado (data)', () async {
      final (env, service, f) = await setup();
      service.debugAfterFirstChunk = (_) => f.writeAsBytesSync(bytes(9, 64 * 1024));
      await service.start();
      await service.waitIdle();
      expect(await statusOf(env, 'video.mp4'), 'changed_during_read');
      expect(await env.count('SELECT COUNT(*) FROM contents'), 0);
    });

    test('mudou entre o escaneamento e a conferência; novo scan devolve para a fila', () async {
      final (env, service, f) = await setup();
      f.writeAsBytesSync(bytes(4, 1000));
      await service.start();
      await service.waitIdle();
      expect(await statusOf(env, 'video.mp4'), 'changed_during_read');
      final reason = await env.db.customSelect('SELECT hash_error FROM file_instances').getSingle();
      expect(reason.read<String>('hash_error'), contains('Escaneie de novo'));

      await env.scan((await env.core.sources.list()).single.id);
      expect(await statusOf(env, 'video.mp4'), 'pending');
      await service.start();
      await service.waitIdle();
      expect(await statusOf(env, 'video.mp4'), 'done');
    });
  });

  test('falha de leitura não é exclusão: arquivo sumido vira erro, não ausente', () async {
    final env = await TestEnv.open();
    final f = env.write('Fotos/some.jpg', bytes(5, 100));
    env.write('Fotos/fica.jpg', bytes(6, 100));
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    f.deleteSync();
    await env.hashAll();
    final row = await env.db
        .customSelect("SELECT hash_status, availability, hash_error FROM file_instances WHERE name = 'some.jpg'")
        .getSingle();
    expect(row.read<String>('hash_status'), 'error');
    expect(row.read<String>('availability'), 'present');
    expect(row.read<String>('hash_error'), contains('não encontrado'));
    expect(await statusOf(env, 'fica.jpg'), 'done');

    // "Tentar de novo" volta para a fila.
    expect(await env.core.hashes.retryFailed(), 1);
    expect(await statusOf(env, 'some.jpg'), 'pending');
  });

  test('somente na nuvem nunca é aberto pela fila', () async {
    final env = await TestEnv.open();
    env.write('Fotos/local.jpg', bytes(7, 100));
    env.write('Fotos/nuvem.jpg', bytes(8, 100));
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    // O scan marca placeholders assim (atributos de nuvem; ver entry_classifier).
    await env.db.customStatement(
      "UPDATE file_instances SET availability = 'cloud_only', hash_status = 'not_applicable' WHERE name = 'nuvem.jpg'",
    );
    await env.hashAll();
    expect(await statusOf(env, 'nuvem.jpg'), 'not_applicable');
    expect(env.core.hashes.current.filesDone, 1);
    // A checagem antes de abrir também reconhece os atributos de placeholder.
    for (final attr in [fileAttributeRecallOnDataAccess, fileAttributeRecallOnOpen, fileAttributeOffline]) {
      expect(SourceFileInfo(size: 1, mtime: 1, attributes: attr | 0x20).isCloudPlaceholder, isTrue);
    }
    expect(const SourceFileInfo(size: 1, mtime: 1, attributes: 0x20).isCloudPlaceholder, isFalse);
  });

  test('fonte desconectada: pendentes ficam pendentes até ela voltar', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 100));
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    final volume = env.volumes.volumes.single;
    env.volumes.volumes = [];
    await env.core.sources.refreshConnectivity();
    await env.hashAll();
    expect(await statusOf(env, 'a.jpg'), 'pending');

    env.volumes.volumes = [volume];
    await env.core.sources.refreshConnectivity();
    await env.hashAll();
    expect(await statusOf(env, 'a.jpg'), 'done');
  });

  test('pausar para entre arquivos; continuar termina sem repetir', () async {
    final env = await TestEnv.open();
    for (var i = 0; i < 10; i++) {
      env.write('Fotos/f$i.jpg', bytes(i, 9000));
    }
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    final service = HashService(env.core.catalog, env.core.sources, env.core.scans, useIsolate: false, chunkSize: 4096);
    addTearDown(service.dispose);
    var seen = 0;
    service.debugAfterFirstChunk = (_) {
      if (++seen == 3) service.pause(); // sem await: só sinaliza
    };
    await service.start();
    await service.waitIdle();
    final done = await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'");
    expect(done, 3, reason: 'o 3º arquivo termina; o resto fica pendente');
    expect(service.current.paused, isTrue);

    service.debugAfterFirstChunk = null;
    await service.start();
    await service.waitIdle();
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE hash_status = 'done'"), 10);
    expect(await env.count('SELECT COUNT(*) FROM contents'), 10);
  });

  test('conferência automática depois do scan', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 100));
    final id = await env.addFolder('Fotos');
    env.core.hashes.enableAuto();
    final finished = env.core.hashes.status.firstWhere((s) => !s.running && s.filesDone == 1);
    await env.scan(id);
    // O scan terminou: a fila começa sozinha.
    await finished.timeout(const Duration(seconds: 30));
    expect(await statusOf(env, 'a.jpg'), 'done');
  });
}
