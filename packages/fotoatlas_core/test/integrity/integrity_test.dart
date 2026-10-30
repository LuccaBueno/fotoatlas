import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 17 + seed * 59) & 0xff);

/// Data fixa e redonda: dá para "devolver" a data depois de mexer no arquivo
/// (corrupção simulada com a data preservada).
final _when = DateTime.utc(2024, 3, 10, 12);

/// Tudo o que importa de uma pasta: conteúdo, tamanho e data de cada arquivo.
Map<String, String> snapshot(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    p.relative(f.path, from: dir.path).replaceAll(r'\', '/'):
        '${sha256.convert(f.readAsBytesSync())} ${f.lengthSync()} ${f.lastModifiedSync().microsecondsSinceEpoch}',
};

/// HD principal ("Fotos", no volume E) com 4 fotos e HD de backup (outro
/// disco físico) com cópias de a e b, com outros nomes.
class Scenario {
  Scenario(this.env, this.hd2, this.fotos, this.backup);
  final TestEnv env;
  final Directory hd2;
  final String fotos;
  final String backup;

  IntegrityService get integrity => env.core.integrity;
  Directory get fotosDir => Directory(p.join(env.volumeDir.path, 'Fotos'));
  File file(String name) => File(p.join(fotosDir.path, name));

  static Future<Scenario> create({bool isolate = false, DeviceBackend? devices}) async {
    final env = await TestEnv.open(isolate: isolate, devices: devices);
    final hd2 = env.addVolume('HD2');
    for (final (name, seed) in [('a.jpg', 1), ('b.jpg', 2), ('c.jpg', 3), ('d.jpg', 4)]) {
      env.write('Fotos/2024/$name', bytes(seed, 4000 + seed)).setLastModifiedSync(_when);
    }
    env
      ..write('Backup/copia_a.jpg', bytes(1, 4001), volume: hd2).setLastModifiedSync(_when)
      ..write('Backup/copia_b.jpg', bytes(2, 4002), volume: hd2).setLastModifiedSync(_when);
    final fotos = await env.addFolder('Fotos', name: 'HD principal');
    final backup = await env.addFolder('Backup', name: 'HD backup', volume: hd2);
    await env.scan(fotos);
    await env.scan(backup);
    await env.hashAll();
    return Scenario(env, hd2, fotos, backup);
  }

  Future<int> instance(String relPath, {String? source}) async =>
      (await env.db
              .customSelect(
                'SELECT id FROM file_instances WHERE source_id = ? AND rel_path = ?',
                variables: [Variable.withString(source ?? fotos), Variable.withString(relPath)],
              )
              .getSingle())
          .read<int>('id');

  Future<Map<String, Object?>> row(int id) async =>
      (await env.db
              .customSelect('SELECT * FROM file_instances WHERE id = ?', variables: [Variable.withInt(id)])
              .getSingle())
          .data;

  /// Troca alguns bytes no meio e devolve a data: "dano no disco".
  void corrupt(String name) {
    final f = file(name);
    final t = f.lastModifiedSync();
    final b = Uint8List.fromList(f.readAsBytesSync());
    for (var i = 100; i < 110; i++) {
      b[i] ^= 0xff;
    }
    f.writeAsBytesSync(b);
    f.setLastModifiedSync(t);
  }

  Future<IntegrityRunView> verifyAll({String? source}) async {
    final id = await integrity.start(VerifyRequest(entries: [VerifyEntry(source ?? fotos)]));
    await integrity.waitIdle();
    return (await integrity.runs()).firstWhere((r) => r.id == id);
  }
}

void main() {
  group('classificação (spec §14, análise C7)', () {
    final a = Uint8List.fromList(List.filled(32, 1));
    final b = Uint8List.fromList(List.filled(32, 2));
    String classify(Uint8List seen, int? mtime, {bool fat = false, int size = 10}) => classifyCheck(
      expectedSha256: a,
      expectedSize: 10,
      expectedMtime: 1000,
      observedSha256: seen,
      observedSize: size,
      observedMtime: mtime,
      fat: fat,
    );

    test('mesmo conteúdo é inalterado, mesmo com outra data', () {
      expect(classify(a, 1000), CheckResult.unchanged);
      expect(classify(a, 5000), CheckResult.unchanged);
    });
    test('conteúdo e data mudaram: alterado (editado)', () {
      expect(classify(b, 5000), CheckResult.changedLegit);
      expect(classify(b, 5000, size: 20), CheckResult.changedLegit);
    });
    test('conteúdo mudou e a data não: possivelmente corrompido (também se o tamanho mudou)', () {
      expect(classify(b, 1000), CheckResult.possiblyCorrupt);
      expect(classify(b, 1000, size: 3), CheckResult.possiblyCorrupt);
    });
    test('FAT: data exatamente ±1 h (horário de verão) não conta como edição', () {
      expect(classify(b, 1000 + fatDstShift, fat: true), CheckResult.possiblyCorrupt);
      expect(classify(b, 1000 - fatDstShift, fat: true), CheckResult.possiblyCorrupt);
      expect(classify(b, 1000 + fatDstShift), CheckResult.changedLegit);
      expect(classify(b, 1000 + fatDstShift + 1, fat: true), CheckResult.changedLegit);
    });
  });

  test('critério da Fase 7: corrupção com a data preservada é detectada, sem mudar nada no disco, '
      'e as outras cópias conferidas são apontadas', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    // b: editado (conteúdo e data novos); c: só a data mudou; d: sumiu.
    s.file('2024/b.jpg')
      ..writeAsBytesSync(bytes(20, 3000))
      ..setLastModifiedSync(DateTime.utc(2025, 1, 2));
    s.file('2024/c.jpg').setLastModifiedSync(DateTime.utc(2025, 1, 3));
    s.file('2024/d.jpg').renameSync(p.join(s.env.temp.path, 'd_fora.jpg'));
    final before = snapshot(s.env.volumeDir);
    final backupBefore = snapshot(s.hd2);

    final run = await s.verifyAll();

    // Só leitura: nenhum arquivo mudou (conteúdo, tamanho e data).
    expect(snapshot(s.env.volumeDir), before);
    expect(snapshot(s.hd2), backupBefore);
    expect(run.status, RunStatus.completed);
    expect(run.filesTotal, 4);
    expect(run.count(CheckResult.possiblyCorrupt), 1);
    expect(run.count(CheckResult.changedLegit), 1);
    expect(run.count(CheckResult.unchanged), 1);
    expect(run.count(CheckResult.missing), 1);

    final a = await s.row(await s.instance('2024/a.jpg'));
    expect(a['integrity'], 'possibly_corrupt');
    expect(a['content_id'], isNull, reason: 'deixa de contar como cópia');
    expect(a['hash_status'], 'error');
    final b = await s.row(await s.instance('2024/b.jpg'));
    expect(b['integrity'], 'changed');
    expect(b['size_bytes'], 3000);
    expect(b['last_verified_at'], isNotNull);
    final c = await s.row(await s.instance('2024/c.jpg'));
    expect(c['integrity'], 'ok');
    expect(c['mtime'], c['hashed_mtime'], reason: 'o catálogo acompanha a data nova');
    // Falha de leitura não é exclusão (regra 10): d continua "presente".
    final d = await s.row(await s.instance('2024/d.jpg'));
    expect(d['availability'], 'present');
    expect(d['integrity'], 'unknown');

    final problems = await s.integrity.problems();
    expect(problems, hasLength(1));
    final problem = problems.single;
    expect(problem.relPath, '2024/a.jpg');
    expect(problem.sourceName, 'HD principal');
    expect(problem.otherCopies.map((c) => (c.sourceName, c.relPath)), [('HD backup', 'copia_a.jpg')]);
    expect(problem.otherCopies.single.connected, isTrue);
    expect(problem.otherCopies.single.samePhysicalDisk, isFalse);
    expect(problem.restorable, hasLength(1));

    final checks = await s.integrity.checks(run.id, results: {CheckResult.possiblyCorrupt});
    expect(checks.single.reason, contains('não foi alterado nem apagado pelo FotoAtlas'));

    final overview = {for (final o in await s.integrity.overview()) o.sourceName: o};
    expect(overview['HD principal']!.possiblyCorrupt, 1);
    expect(overview['HD principal']!.lastVerifiedAt, isNotNull);
    expect(overview['HD backup']!.lastVerifiedAt, isNull);
  });

  test('o arquivo danificado não volta a "conferido" por "tentar de novo" nem por um novo escaneamento', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    await s.verifyAll();
    final id = await s.instance('2024/a.jpg');

    expect(await s.env.core.hashes.retryFailed(), 0);
    await s.env.scan(s.fotos);
    await s.env.hashAll();
    var a = await s.row(id);
    expect(a['integrity'], 'possibly_corrupt');
    expect(a['content_id'], isNull);
    expect(a['hash_status'], 'error');

    // Gravado de novo (data nova): aí sim volta a ser um arquivo comum.
    s.file('2024/a.jpg').setLastModifiedSync(DateTime.utc(2025, 6, 1));
    await s.env.scan(s.fotos);
    await s.env.hashAll();
    a = await s.row(id);
    expect(a['integrity'], 'unknown');
    expect(a['hash_status'], 'done');
  });

  test('restaurar: cópia segura a partir da outra cópia, com prévia, ao lado do danificado, sem substituir', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    await s.verifyAll();
    final damaged = s.file('2024/a.jpg').readAsBytesSync();
    final problem = (await s.integrity.problems()).single;

    final request = await s.integrity.restoreRequest(
      problem.instanceId,
      fromInstanceId: problem.otherCopies.single.instanceId,
    );
    expect(request.destSourceId, s.fotos);
    expect(request.destFolder, '2024');
    expect(request.origin, 'restore');
    // Nada é gravado antes de confirmar.
    final preview = await s.env.core.copies.preview(request);
    expect(preview.canStart, isTrue);
    expect(preview.items.single.srcSourceId, s.backup);
    expect(preview.items.single.dstRelPath, '2024/a_1.jpg');
    expect(preview.items.single.renamedForConflict, isTrue);
    expect(s.file('2024/a_1.jpg').existsSync(), isFalse);

    await s.env.core.copies.start(preview);
    await s.env.core.copies.waitIdle();
    expect(s.file('2024/a_1.jpg').readAsBytesSync(), bytes(1, 4001));
    expect(s.file('2024/a.jpg').readAsBytesSync(), damaged, reason: 'o danificado nunca é substituído nem apagado');
    final restored = await s.row(await s.instance('2024/a_1.jpg'));
    expect(restored['integrity'], 'ok');
    expect(restored['hash_status'], 'done');
    // O problema continua listado (o arquivo danificado ainda está lá), agora
    // com a cópia restaurada no mesmo disco.
    final again = (await s.integrity.problems()).single;
    expect(again.otherCopies.where((c) => c.sameSource).single.relPath, '2024/a_1.jpg');
  });

  test('restaurar de uma cópia que também se estragou: a cópia segura recusa', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    await s.verifyAll();
    final problem = (await s.integrity.problems()).single;
    // A "boa" também se estragou depois da última conferência.
    final other = File(p.join(s.hd2.path, 'Backup', 'copia_a.jpg'));
    final b = other.readAsBytesSync()..[5] ^= 0xff;
    other.writeAsBytesSync(b);
    other.setLastModifiedSync(_when);

    final request = await s.integrity.restoreRequest(
      problem.instanceId,
      fromInstanceId: problem.otherCopies.single.instanceId,
    );
    final op = await s.env.core.copies.start(await s.env.core.copies.preview(request));
    await s.env.core.copies.waitIdle();
    final view = (await s.env.core.copies.view(op))!;
    expect(view.failed, 1);
    expect(s.file('2024/a_1.jpg').existsSync(), isFalse);
  });

  test('restaurar só quando faz sentido: celular não é destino e a cópia tem de ter o conteúdo', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    await s.verifyAll();
    final problem = (await s.integrity.problems()).single;
    final wrong = await s.instance('2024/c.jpg');
    // A cópia escolhida tem outro conteúdo.
    await expectLater(
      s.integrity.restoreRequest(problem.instanceId, fromInstanceId: wrong),
      throwsA(isA<StateError>()),
    );
    // O arquivo não está marcado como danificado.
    await expectLater(
      s.integrity.restoreRequest(wrong, fromInstanceId: problem.otherCopies.single.instanceId),
      throwsA(isA<StateError>()),
    );
  });

  test('aceitar como está: só o catálogo muda e o arquivo volta para a conferência', () async {
    final s = await Scenario.create();
    s.corrupt('2024/a.jpg');
    await s.verifyAll();
    final before = snapshot(s.env.volumeDir);
    final id = await s.instance('2024/a.jpg');
    expect(await s.integrity.acceptAsIs(id), isTrue);
    await s.env.hashAll();
    expect(snapshot(s.env.volumeDir), before);
    final a = await s.row(id);
    expect(a['hash_status'], 'done');
    expect(a['integrity'], 'unknown');
    expect(await s.integrity.problems(), isEmpty);
  });

  test('pausar, continuar e fechar no meio: cada arquivo verificado uma vez só', () async {
    final s = await Scenario.create();
    for (var i = 0; i < 12; i++) {
      s.env.write('Fotos/mais/f$i.jpg', bytes(100 + i, 2000));
    }
    await s.env.scan(s.fotos);
    await s.env.hashAll();

    // "Pausar" logo depois de "Verificar": a rodada para antes de ler tudo.
    final id = (await s.integrity.start(VerifyRequest(entries: [VerifyEntry(s.fotos)])))!;
    await s.integrity.pause(id);
    var run = (await s.integrity.runs()).single;
    expect(run.status, RunStatus.paused);
    expect(run.pausedByUser, isTrue);
    expect(run.filesChecked, lessThan(16));
    // Pausada pelo usuário: o agendamento não continua sozinho.
    await s.integrity.setSchedule(const IntegritySchedule(everyDays: 0));
    expect(await s.integrity.scheduleTick(), isNot(id));
    await s.integrity.waitIdle();

    // Continua, fecha o app no meio (fica "interrompida") e continua de novo.
    await s.integrity.resume(id);
    await s.env.reopen();
    run = (await s.env.core.integrity.runs()).firstWhere((r) => r.id == id);
    expect(run.status, RunStatus.paused);
    expect(run.pausedByUser, isFalse);
    await s.env.core.integrity.resume(id);
    await s.env.core.integrity.waitIdle();
    run = (await s.env.core.integrity.runs()).firstWhere((r) => r.id == id);
    expect(run.status, RunStatus.completed);
    expect(run.filesChecked, 16);
    final dup = await s.env.count(
      'SELECT COUNT(*) FROM (SELECT instance_id FROM integrity_checks WHERE run_id = ? '
      'GROUP BY instance_id HAVING COUNT(*) > 1)',
      [id],
    );
    expect(dup, 0);
  });

  test('fonte desconectada no meio: a rodada espera, nada vira "ausente", e termina quando volta', () async {
    final s = await Scenario.create();
    final id = (await s.integrity.start(VerifyRequest(entries: [VerifyEntry(s.fotos)])))!;
    await s.integrity.pause(id);
    // "Desplugar": a pasta some.
    final away = Directory(p.join(s.env.temp.path, 'fotos_fora'));
    s.fotosDir.renameSync(away.path);
    await s.integrity.resume(id);
    await s.integrity.waitIdle();
    var run = (await s.integrity.runs()).single;
    expect(run.status, RunStatus.paused);
    expect(run.message, contains('não está acessível agora'));
    expect(run.count(CheckResult.missing), 0);
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);

    away.renameSync(s.fotosDir.path);
    await s.integrity.resume(id);
    await s.integrity.waitIdle();
    run = (await s.integrity.runs()).single;
    expect(run.status, RunStatus.completed);
    expect(run.count(CheckResult.unchanged), 4);
  });

  test('periódica: leve, só o que passou do prazo, cede a vez às outras tarefas e nunca lê celulares', () async {
    final devices = FakeDeviceBackend()..phones.add(FakePhone()..put('Interno/DCIM/IMG_1.jpg', bytes(1, 4001)));
    final s = await Scenario.create(devices: devices);
    await s.env.core.sources.refreshConnectivity();
    final phone = (await s.env.core.sources.addPhone(devices.phones.single.deviceId)).sourceId;
    await s.env.scan(phone);
    await s.env.hashAll();
    final phoneReads = devices.hashCalls;

    // Tudo conferido agora: com o prazo de 90 dias, nada a fazer.
    expect(await s.integrity.scheduleTick(), isNull);
    // Desligada: nada.
    await s.integrity.setSchedule(const IntegritySchedule(enabled: false, everyDays: 0));
    expect(await s.integrity.scheduleTick(), isNull);

    await s.integrity.setSchedule(const IntegritySchedule(everyDays: 0));
    final progress = <IntegrityProgress>[];
    final sub = s.integrity.progress.listen(progress.add);
    final id = await s.integrity.scheduleTick();
    expect(id, isNotNull);
    await s.integrity.waitIdle();
    await sub.cancel();
    final run = (await s.integrity.runs()).firstWhere((r) => r.id == id);
    expect(run.scheduled, isTrue);
    expect(run.status, RunStatus.completed);
    expect(run.filesTotal, 6, reason: '4 do HD principal + 2 do backup; o celular fica de fora');
    expect(run.includesPhone, isFalse);
    expect(devices.hashCalls, phoneReads, reason: 'o celular não foi lido');
    expect(progress.every((p) => p.light), isTrue);

    // Recém-verificado: com prazo de 1 dia, nada a fazer.
    await s.integrity.setSchedule(const IntegritySchedule(everyDays: 1));
    expect(await s.integrity.scheduleTick(), isNull);
  });

  test('periódica espera outra tarefa: pausa sozinha e continua no próximo passo', () async {
    var busy = false;
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 300000));
    env.write('Fotos/b.jpg', bytes(2, 300000));
    final src = await env.addFolder('Fotos', name: 'HD');
    await env.scan(src);
    await env.hashAll();
    final service = IntegrityService(
      env.core.catalog,
      env.core.sources,
      useIsolate: false,
      busy: () => busy,
      lightRate: 200000, // ~1,5 s por arquivo: dá tempo de "começar outra tarefa"
      chunkSize: 64 * 1024,
    );
    addTearDown(service.dispose);
    await service.setSchedule(const IntegritySchedule(everyDays: 0));
    busy = true;
    expect(await service.scheduleTick(), isNull);
    busy = false;
    final id = (await service.scheduleTick())!;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    busy = true;
    await service.waitIdle();
    var run = (await service.runs()).single;
    expect(run.status, RunStatus.paused);
    expect(run.pausedByUser, isFalse);
    expect(run.message, contains('Esperando outras tarefas'));
    busy = false;
    expect(await service.scheduleTick(), id);
    await service.waitIdle();
    run = (await service.runs()).single;
    expect(run.status, RunStatus.completed);
    expect(run.count(CheckResult.unchanged), 2);
  });

  test('leve: a leitura não passa do limite, nem depois de ficar parada', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 256 * 1024));
    env.write('Fotos/b.jpg', bytes(2, 256 * 1024));
    final src = await env.addFolder('Fotos', name: 'HD');
    await env.scan(src);
    await env.hashAll();
    final service = IntegrityService(
      env.core.catalog,
      env.core.sources,
      useIsolate: false,
      lightRate: 256 * 1024, // 1 arquivo por segundo
      chunkSize: 64 * 1024,
    );
    addTearDown(service.dispose);
    await service.setSchedule(const IntegritySchedule(everyDays: 0));
    final watch = Stopwatch()..start();
    await service.scheduleTick();
    await service.waitIdle();
    // 512 KB a 256 KB/s: pelo menos ~2 s (o primeiro bloco não espera).
    expect(watch.elapsed, greaterThan(const Duration(milliseconds: 1700)));
    expect((await service.runs()).single.count(CheckResult.unchanged), 2);
  });

  test('celular só quando o usuário pede: corrupção no celular detectada sem gravar nada nele', () async {
    final pixel = FakePhone()
      ..put('Interno/DCIM/IMG_1.jpg', bytes(1, 4001))
      ..put('Interno/DCIM/IMG_2.jpg', bytes(7, 800));
    final devices = FakeDeviceBackend()..phones.add(pixel);
    final s = await Scenario.create(devices: devices);
    await s.env.core.sources.refreshConnectivity();
    final phone = (await s.env.core.sources.addPhone(pixel.deviceId)).sourceId;
    await s.env.scan(phone);
    await s.env.hashAll();
    // Pela Biblioteca (conteúdos), o celular nunca entra.
    final contents = [
      for (final r in await s.env.db.customSelect('SELECT DISTINCT content_id FROM file_instances').get())
        ?r.readNullable<int>('content_id'),
    ];
    final library = await s.integrity.estimate(VerifyRequest(contentIds: contents));
    expect(library.phoneFiles, 0);
    expect(library.files, 6);

    final estimate = await s.integrity.estimate(VerifyRequest(entries: [VerifyEntry(phone)]));
    expect(estimate.phoneFiles, 2);
    // Mesmo tamanho e mesma data, bytes diferentes.
    final damaged = List.of(pixel.files['Interno/DCIM/IMG_2.jpg']!)..[10] ^= 0xff;
    pixel.files['Interno/DCIM/IMG_2.jpg'] = damaged;
    final run = await s.verifyAll(source: phone);
    expect(run.includesPhone, isTrue);
    expect(run.count(CheckResult.unchanged), 1);
    expect(run.count(CheckResult.possiblyCorrupt), 1);
    expect(pixel.files['Interno/DCIM/IMG_2.jpg'], damaged);
    final problem = (await s.integrity.problems()).single;
    expect(problem.sourceName, 'Pixel de Teste');
    expect(problem.otherCopies, isEmpty);
    await expectLater(s.integrity.restoreRequest(problem.instanceId, fromInstanceId: 1), throwsA(isA<StateError>()));
  });

  test('em isolate: mesma classificação e a rodada termina', () async {
    final s = await Scenario.create(isolate: true);
    s.corrupt('2024/a.jpg');
    final run = await s.verifyAll();
    expect(run.status, RunStatus.completed);
    expect(run.count(CheckResult.possiblyCorrupt), 1);
    expect(run.count(CheckResult.unchanged), 3);
  });

  test('nada para verificar: a rodada não fica aberta', () async {
    final env = await TestEnv.open();
    final src = await env.addFolder('Vazia', name: 'Vazia');
    await env.scan(src);
    expect(await env.core.integrity.start(VerifyRequest(entries: [VerifyEntry(src)])), isNull);
    expect((await env.core.integrity.runs()).single.status, RunStatus.completed);
  });
}
