import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);

String sha(List<int> b) => sha256.convert(b).toString();

/// Hash de todos os arquivos de uma pasta (caminho relativo → sha), para
/// conferir que nada mudou.
Map<String, String> tree(Directory dir) => {
  if (dir.existsSync())
    for (final f in dir.listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: dir.path).replaceAll(r'\', '/'): sha(f.readAsBytesSync()),
};

/// Origem (HD antigo) com 4 fotos e destino (HD de backup) que já tem uma.
class CopyScenario {
  CopyScenario(this.env, this.hd2, this.src, this.dst);
  final TestEnv env;
  final Directory hd2;
  final String src;
  final String dst;

  Directory get srcDir => Directory(p.join(env.volumeDir.path, 'Antigo'));
  Directory get dstDir => Directory(p.join(hd2.path, 'Backup'));
  CopyService get copies => env.core.copies;

  static Future<CopyScenario> create({FreeSpaceProbe? freeSpace, String fs = 'NTFS', DeviceBackend? devices}) async {
    final env = await TestEnv.open(freeSpace: freeSpace, devices: devices);
    final hd2 = Directory(p.join(env.temp.path, 'volume_HD2'))..createSync();
    env.volumes.volumes = [...env.volumes.volumes, _vol(hd2.path, fs)];
    env
      ..write('Antigo/fotos/IMG_0001.jpg', bytes(1, 3000))
      ..write('Antigo/fotos/IMG_0002.jpg', bytes(2, 5000))
      ..write('Antigo/fotos/sub/VID_0001.mp4', bytes(3, 9000))
      ..write('Antigo/outras/IMG_0004.jpg', bytes(4, 700))
      ..write('Backup/ja_tenho.jpg', bytes(1, 3000), volume: hd2);
    final src = await env.addFolder('Antigo', name: 'HD antigo');
    final dst = await env.addFolder('Backup', name: 'HD backup', volume: hd2);
    await env.scan(src);
    await env.scan(dst);
    await env.hashAll();
    return CopyScenario(env, hd2, src, dst);
  }

  static VolumeInfo _vol(String dir, String fs) => VolumeInfo(
    guidPath: '$dir\\',
    mountPoints: const [r'G:\'],
    label: 'HD2',
    fileSystem: fs,
    serial: 0x7777,
    totalBytes: 1 << 30,
    freeBytes: 1 << 29,
    driveType: 'fixed',
    physicalDisks: const [
      PhysicalDiskInfo(
        diskNumber: 3,
        serial: 'DISCO-HD2',
        model: 'Disco Teste',
        sizeBytes: 1 << 30,
        busType: 'usb',
        identityConfidence: 'reliable',
      ),
    ],
  );

  Future<List<int>> allContents() async => [
    for (final r
        in await env.db
            .customSelect(
              'SELECT DISTINCT content_id FROM file_instances WHERE source_id = ? AND content_id IS NOT NULL',
              variables: [Variable.withString(src)],
            )
            .get())
      r.read<int>('content_id'),
  ];

  Future<CopyPreview> preview({
    String template = '{original}',
    ConflictPolicy conflict = ConflictPolicy.suffix,
    String folder = '',
    List<int>? contents,
  }) async => copies.preview(
    CopyRequest(
      contentIds: contents ?? await allContents(),
      destSourceId: dst,
      destFolder: folder,
      template: template,
      conflict: conflict,
      preferSourceIds: [src],
    ),
  );

  Future<OperationView> run(CopyPreview preview) async {
    final id = await copies.start(preview);
    await copies.waitIdle();
    return (await copies.view(id))!;
  }

  Future<Map<String, int>> states(String op) async => {
    for (final r
        in await env.db
            .customSelect(
              'SELECT state, COUNT(*) AS n FROM operation_items WHERE operation_id = ? GROUP BY state',
              variables: [Variable.withString(op)],
            )
            .get())
      r.read<String>('state'): r.read<int>('n'),
  };

  List<String> parts() {
    final tmp = Directory(p.join(dstDir.path, '.fotoatlas-tmp'));
    return tmp.existsSync() ? [for (final f in tmp.listSync()) p.basename(f.path)] : const [];
  }
}

void main() {
  group('nomes', () {
    test('sanitização determinística para o Windows', () {
      expect(sanitizeName('foto:1?.jpg'), 'foto_1_.jpg');
      expect(sanitizeName('CON.jpg'), '_CON.jpg');
      expect(sanitizeName('nul'), '_nul');
      expect(sanitizeName('com1.txt'), '_com1.txt');
      expect(sanitizeName('fim. . '), 'fim');
      expect(sanitizeName('...'), '_');
      expect(sanitizeName('a\u0001b.jpg'), 'a_b.jpg');
      final long = '${'x' * 300}.jpeg';
      expect(sanitizeName(long).length, 255);
      expect(sanitizeName(long), endsWith('.jpeg'));
      expect(sanitizeName('Normal (1).JPG'), 'Normal (1).JPG');
    });

    test('modelos de pasta', () {
      const dated = TemplateVars(year: 2024, month: 7, day: 3, originalDir: 'DCIM/Camera', mediaType: 'photo');
      const undated = TemplateVars(originalDir: 'a/b', mediaType: 'video');
      expect(renderFolder('{ano}/{ano}-{mes}', dated), '2024/2024-07');
      expect(renderFolder('{ano}/{ano}-{mes}-{dia}', dated), '2024/2024-07-03');
      expect(renderFolder('{original}', dated), 'DCIM/Camera');
      expect(renderFolder('', dated), '');
      expect(renderFolder('{ano}/{ano}-{mes}', undated), undatedFolder);
      expect(renderFolder('{tipo}/{ano}', undated), 'Vídeos/$undatedFolder');
      expect(renderFolder('{tipo}/{ano}', dated), 'Fotos/2024');
      expect(withSuffix('IMG.jpg', 2), 'IMG_2.jpg');
      expect(withSuffix('LEIAME', 1), 'LEIAME_1');
    });
  });

  test('copia o que falta: prévia, protocolo completo, catálogo e origem intacta', () async {
    final s = await CopyScenario.create();
    final srcBefore = tree(s.srcDir);
    final preview = await s.preview();
    expect(preview.alreadyThere, 1, reason: 'IMG_0001 já está no backup com outro nome');
    expect(
      preview.items.map((i) => i.dstRelPath),
      unorderedEquals(['fotos/IMG_0002.jpg', 'fotos/sub/VID_0001.mp4', 'outras/IMG_0004.jpg']),
    );
    expect(preview.totalBytes, 5000 + 9000 + 700);
    expect(preview.canStart, isTrue);
    expect(preview.folders.map((f) => f.relPath), ['fotos', 'fotos/sub', 'outras']);

    final op = await s.run(preview);
    expect(op.status, OpStatus.completed);
    expect(op.published, 3);
    expect(tree(s.srcDir), srcBefore, reason: 'a origem não muda');
    final dst = tree(s.dstDir);
    expect(dst['fotos/IMG_0002.jpg'], sha(bytes(2, 5000)));
    expect(dst['fotos/sub/VID_0001.mp4'], sha(bytes(3, 9000)));
    expect(dst['ja_tenho.jpg'], sha(bytes(1, 3000)));
    expect(s.parts(), isEmpty, reason: 'nenhum .part sobra');
    // Data de modificação preservada.
    final srcM = File(p.join(s.srcDir.path, 'fotos', 'IMG_0002.jpg')).lastModifiedSync();
    expect(File(p.join(s.dstDir.path, 'fotos', 'IMG_0002.jpg')).lastModifiedSync(), srcM);

    // Catálogo: o destino passa a ter tudo, já conferido (comparação 100%).
    final cmp = await s.env.core.compare.compare(Scope([ScopeEntry(s.src, '')]), Scope([ScopeEntry(s.dst, '')]));
    expect(cmp.verdict, CompareVerdict.complete);
    // Diário: cada item passou por todos os estados, em ordem.
    final events = await s.env.db
        .customSelect(
          'SELECT to_state FROM operation_events WHERE operation_id = ? AND item_id = (SELECT MIN(id) FROM operation_items WHERE operation_id = ?) ORDER BY id',
          variables: [Variable.withString(op.id), Variable.withString(op.id)],
        )
        .get();
    expect(events.map((e) => e.read<String>('to_state')), [
      'copying',
      'copied',
      'verifying',
      'verified',
      'publishing',
      'published',
    ]);
    // Nada mais a copiar.
    final again = await s.preview();
    expect(again.items, isEmpty);
    expect(again.alreadyThere, 4);
    final csv = await s.copies.exportCsv(op.id);
    expect(csv, contains('fotos/IMG_0002.jpg'));
    expect(csv, contains(sha(bytes(2, 5000))));
  });

  test('isolate: a cópia roda fora do isolate principal com o mesmo resultado', () async {
    final env = await TestEnv.open(isolate: true);
    final hd2 = env.addVolume('HD2');
    env.write('A/x.jpg', bytes(7, 3 << 20));
    final a = await env.addFolder('A');
    final b = await env.addFolder('B', volume: hd2);
    await env.scan(a);
    await env.scan(b);
    await env.hashAll();
    final ids = await env.core.compare.missingContentIds(Scope([ScopeEntry(a, '')]), Scope([ScopeEntry(b, '')]));
    final preview = await env.core.copies.preview(CopyRequest(contentIds: ids, destSourceId: b, template: ''));
    final id = await env.core.copies.start(preview);
    await env.core.copies.waitIdle();
    expect((await env.core.copies.view(id))!.status, OpStatus.completed);
    expect(sha(File(p.join(hd2.path, 'B', 'x.jpg')).readAsBytesSync()), sha(bytes(7, 3 << 20)));
  });

  test('conflito de nome: sufixo, nunca sobrescreve; "perguntar" deixa decidir', () async {
    final s = await CopyScenario.create();
    // Arquivo diferente com o mesmo nome no destino (fora do catálogo).
    final other = File(p.join(s.dstDir.path, 'fotos', 'IMG_0002.jpg'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes(99, 123));
    final preview = await s.preview();
    final planned = preview.items.singleWhere((i) => i.srcRelPath.endsWith('IMG_0002.jpg'));
    expect(planned.dstRelPath, 'fotos/IMG_0002_1.jpg');
    expect(preview.renamedForConflict, 1);
    final first = await s.run(preview);
    expect(sha(other.readAsBytesSync()), sha(bytes(99, 123)), reason: 'o arquivo que já existia ficou intacto');
    // Os detalhes da tarefa sabem quem foi salvo com outro nome.
    final renamed = (await s.copies.items(first.id)).where((i) => i.renamedForConflict).toList();
    expect(renamed.map((i) => (i.srcName, i.dstName)), [('IMG_0002.jpg', 'IMG_0002_1.jpg')]);
    expect(sha(File(p.join(s.dstDir.path, 'fotos', 'IMG_0002_1.jpg')).readAsBytesSync()), sha(bytes(2, 5000)));

    // Política "perguntar": o item espera a decisão, já conferido.
    final s2 = await CopyScenario.create();
    File(p.join(s2.dstDir.path, 'fotos', 'IMG_0002.jpg'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes(98, 50));
    File(p.join(s2.dstDir.path, 'fotos', 'sub', 'VID_0001.mp4'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes(97, 60));
    final ask = await s2.preview(conflict: ConflictPolicy.ask);
    expect(ask.askConflicts, 2);
    final op = await s2.run(ask);
    expect(op.status, OpStatus.needsAttention);
    expect(op.needsAttention, 2);
    final waiting = await s2.copies.items(op.id, states: {ItemState.needsAttention});
    expect(waiting.map((w) => w.errorCode), everyElement('name_conflict'));
    expect(s2.parts(), hasLength(2), reason: 'os .part conferidos esperam a decisão');
    final img = waiting.singleWhere((w) => w.srcRelPath.endsWith('IMG_0002.jpg'));
    final vid = waiting.singleWhere((w) => w.srcRelPath.endsWith('VID_0001.mp4'));
    await s2.copies.resolveConflict(img.id, rename: true);
    await s2.copies.waitIdle();
    await s2.copies.resolveConflict(vid.id, rename: false);
    final done = (await s2.copies.view(op.id))!;
    expect(done.status, OpStatus.completed);
    expect(sha(File(p.join(s2.dstDir.path, 'fotos', 'IMG_0002_1.jpg')).readAsBytesSync()), sha(bytes(2, 5000)));
    expect(sha(File(p.join(s2.dstDir.path, 'fotos', 'IMG_0002.jpg')).readAsBytesSync()), sha(bytes(98, 50)));
    expect(sha(File(p.join(s2.dstDir.path, 'fotos', 'sub', 'VID_0001.mp4')).readAsBytesSync()), sha(bytes(97, 60)));
    expect(s2.parts(), isEmpty);
  });

  test('destino já tem o arquivo idêntico (fora do catálogo): não duplica', () async {
    final s = await CopyScenario.create();
    File(p.join(s.dstDir.path, 'fotos', 'IMG_0002.jpg'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes(2, 5000));
    final preview = await s.preview();
    // O catálogo não sabe (destino não reescaneado): a prévia vê o nome ocupado...
    expect(preview.items.singleWhere((i) => i.srcRelPath.endsWith('IMG_0002.jpg')).renamedForConflict, isTrue);
    // ...e nesse caso pede um nome novo. Já com a política de perguntar, a
    // conferência no momento de publicar descobre que é idêntico.
    final ask = await s.preview(conflict: ConflictPolicy.ask);
    final op = await s.run(ask);
    expect(await s.states(op.id), {ItemState.published: 2, ItemState.skippedIdentical: 1});
    expect(File(p.join(s.dstDir.path, 'fotos', 'IMG_0002_1.jpg')).existsSync(), isFalse);
  });

  test('falta de espaço: a prévia avisa e a cópia pausa sem deixar nada pela metade', () async {
    var free = 1 << 40;
    final s = await CopyScenario.create(freeSpace: (_) => free);
    free = 1000;
    final tight = await s.preview();
    expect(tight.enoughSpace, isFalse);
    expect(tight.canStart, isFalse);
    await expectLater(s.copies.start(tight), throwsStateError);

    // Espaço some no meio (outro programa gravou): pausa antes do próximo arquivo.
    var calls = 0;
    final s2 = await CopyScenario.create(freeSpace: (_) => ++calls >= 3 ? 1000 : 1 << 40);
    final op = await s2.run(await s2.preview());
    expect(op.status, OpStatus.paused);
    expect(op.pauseReason, contains('espaço'));
    expect(op.published, 1);
    expect(await s2.states(op.id), {ItemState.published: 1, ItemState.pending: 2});
    expect(s2.parts(), isEmpty);
    calls = -1000;
    await s2.copies.resume(op.id);
    await s2.copies.waitIdle();
    expect((await s2.copies.view(op.id))!.status, OpStatus.completed);
  });

  test('FAT32: arquivo acima de 4 GB fica de fora na prévia e é recusado na cópia', () async {
    final s = await CopyScenario.create(fs: 'FAT32');
    // O catálogo diz que um dos arquivos tem 5 GB (sem criar 5 GB no disco).
    await s.env.db.customStatement(
      "UPDATE file_instances SET size_bytes = 5368709120 WHERE rel_path = 'fotos/sub/VID_0001.mp4'",
    );
    final preview = await s.preview();
    expect(preview.tooLargeForFat32.single.name, 'VID_0001.mp4');
    expect(preview.items.map((i) => i.srcRelPath), isNot(contains('fotos/sub/VID_0001.mp4')));

    // Mesmo que um item grande entre no diário, o executor recusa antes de gravar.
    final ntfs = await CopyScenario.create();
    await ntfs.env.db.customStatement(
      "UPDATE file_instances SET size_bytes = 5368709120 WHERE rel_path = 'fotos/sub/VID_0001.mp4'",
    );
    final big = await ntfs.preview();
    expect(big.items.map((i) => i.srcRelPath), contains('fotos/sub/VID_0001.mp4'));
    await ntfs.env.db.customStatement("UPDATE sources SET filesystem = 'FAT32' WHERE id = '${ntfs.dst}'");
    final op = await ntfs.run(big);
    final failed = await ntfs.copies.items(op.id, states: {ItemState.failed});
    expect(failed.single.errorCode, 'too_large_for_fs');
    expect(ntfs.parts(), isEmpty);
  });

  test('origem que some no meio: pasta renomeada falha o item; fonte inteira some pausa', () async {
    late CopyScenario s;
    var calls = 0;
    s = await CopyScenario.create(
      freeSpace: (_) {
        // 1ª chamada = prévia, 2ª = antes do 1º item; antes do 2º, a pasta some.
        if (++calls == 3) {
          Directory(p.join(s.srcDir.path, 'fotos', 'sub')).renameSync(p.join(s.srcDir.path, 'fotos', 'sub2'));
        }
        return 1 << 40;
      },
    );
    final op = await s.run(await s.preview());
    expect(op.status, OpStatus.completedWithErrors);
    final failed = await s.copies.items(op.id, states: {ItemState.failed});
    expect(failed.single.srcRelPath, 'fotos/sub/VID_0001.mp4');
    expect(failed.single.errorCode, 'source_missing');
    expect(s.parts(), isEmpty);
    // Falha de leitura não é exclusão (regra 10): o catálogo não marca ausente.
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);

    late CopyScenario s2;
    var calls2 = 0;
    s2 = await CopyScenario.create(
      freeSpace: (_) {
        if (++calls2 == 3) s2.srcDir.renameSync('${s2.srcDir.path}_fora');
        return 1 << 40;
      },
    );
    final op2 = await s2.run(await s2.preview());
    expect(op2.status, OpStatus.paused, reason: 'a origem inteira saiu: pausa, não falha');
    expect(await s2.states(op2.id), {ItemState.published: 1, ItemState.pending: 2});
    Directory('${s2.srcDir.path}_fora').renameSync(s2.srcDir.path);
    await s2.copies.resume(op2.id);
    await s2.copies.waitIdle();
    expect((await s2.copies.view(op2.id))!.status, OpStatus.completed);
  });

  test('celular desconectado no meio da cópia: pausa, descarta o parcial e retoma', () async {
    final devices = FakeDeviceBackend();
    final phone = FakePhone()
      ..put('Interno/DCIM/Camera/IMG_1.jpg', bytes(11, 4000))
      ..put('Interno/DCIM/Camera/IMG_2.jpg', bytes(12, 6000));
    devices.phones.add(phone);
    final env = await TestEnv.open(devices: devices);
    final hd = env.addVolume('HD');
    await env.core.sources.refreshConnectivity();
    final cel = (await env.core.sources.addPhone(phone.deviceId)).sourceId;
    final dst = await env.addFolder('Backup', volume: hd);
    await env.scan(cel);
    await env.scan(dst);
    await env.hashAll();
    final ids = await env.core.compare.missingContentIds(Scope([ScopeEntry(cel, '')]), Scope([ScopeEntry(dst, '')]));
    expect(ids, hasLength(2));
    devices.disconnectDuringPull.add('Interno/DCIM/Camera/IMG_2.jpg');
    final preview = await env.core.copies.preview(
      CopyRequest(contentIds: ids, destSourceId: dst, template: '{original}'),
    );
    final id = await env.core.copies.start(preview);
    await env.core.copies.waitIdle();
    var op = (await env.core.copies.view(id))!;
    expect(op.status, OpStatus.paused);
    expect(op.pauseReason, contains('desconectado'));
    final tmp = Directory(p.join(hd.path, 'Backup', '.fotoatlas-tmp'));
    expect(tmp.listSync(), isEmpty, reason: 'o parcial (nosso) foi descartado');
    expect(op.published, 1);

    // Reconecta (IDs de objeto novos, como no Android) e continua.
    phone.session++;
    devices.phones.add(phone);
    await env.core.sources.refreshConnectivity();
    await env.core.copies.resume(id);
    await env.core.copies.waitIdle();
    op = (await env.core.copies.view(id))!;
    expect(op.status, OpStatus.completed);
    final out = File(p.join(hd.path, 'Backup', 'Interno', 'DCIM', 'Camera', 'IMG_2.jpg'));
    expect(sha(out.readAsBytesSync()), sha(bytes(12, 6000)));
  });

  test('pausar, continuar e cancelar; o que já foi copiado fica', () async {
    late CopyScenario s;
    var calls = 0;
    String? opId;
    s = await CopyScenario.create(
      freeSpace: (_) {
        if (++calls == 3 && opId != null) s.copies.pause(opId).ignore();
        return 1 << 40;
      },
    );
    final preview = await s.preview();
    opId = await s.copies.start(preview);
    await s.copies.waitIdle();
    var op = (await s.copies.view(opId))!;
    expect(op.status, OpStatus.paused);
    expect(op.published, greaterThanOrEqualTo(1));
    expect(s.parts(), isEmpty);
    await s.copies.cancel(opId);
    op = (await s.copies.view(opId))!;
    expect(op.status, OpStatus.cancelled);
    expect(File(p.join(s.dstDir.path, 'fotos', 'IMG_0002.jpg')).existsSync(), isTrue, reason: 'nada é apagado');
  });

  test('pasta temporária: arquivos desconhecidos são listados e nunca apagados', () async {
    final s = await CopyScenario.create();
    final unknown = File(p.join(s.dstDir.path, '.fotoatlas-tmp', 'misterio.part'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3]);
    final other = File(p.join(s.dstDir.path, '.fotoatlas-tmp', 'anotacao.txt'))..writeAsStringSync('x');
    await s.run(await s.preview());
    await s.env.reopen();
    await s.env.core.copies.recoverAll();
    expect(unknown.existsSync(), isTrue);
    expect(other.existsSync(), isTrue);
    final left = await s.env.core.copies.tempLeftovers(s.dst);
    expect(left!.map((l) => l.name), unorderedEquals(['misterio.part', 'anotacao.txt']));
  });

  test('recuperação: reabrir sem nada pendente não muda nada', () async {
    final s = await CopyScenario.create();
    final op = await s.run(await s.preview());
    Future<String> snapshot() async => [
      for (final r
          in await s.env.db
              .customSelect('SELECT state, dst_rel_path_final, updated_at FROM operation_items ORDER BY id')
              .get())
        r.data.toString(),
      (await s.env.count('SELECT COUNT(*) FROM operation_events')).toString(),
      (await s.copies.view(op.id))!.status,
    ].join('|');
    final before = await snapshot();
    for (var i = 0; i < 3; i++) {
      await s.env.reopen();
      final report = await s.env.core.copies.recoverAll();
      expect(report.changedSomething, isFalse);
      expect(await snapshot(), before);
    }
  });

  test('destino desconectado: a prévia bloqueia e celular não é destino', () async {
    final s = await CopyScenario.create();
    s.env.volumes.volumes = [s.env.volumes.volumes.first];
    await s.env.core.sources.refreshConnectivity();
    final preview = await s.preview();
    expect(preview.canStart, isFalse);
    expect(preview.blocker, contains('desconectado'));
  });
}
