import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101 + (i >> 7)) & 0xff);
String sha(List<int> b) => sha256.convert(b).toString();

/// "HD" com repetidos (mesmo conteúdo, mesmo dispositivo): a foto A em três
/// lugares (uma numa pasta de data, uma com "(1)" no nome), o vídeo B em dois,
/// uma foto única e um repetido que não é foto (não entra). Um segundo
/// dispositivo tem outra cópia de A (nunca se mistura).
class Scenario {
  Scenario(this.env, this.hd, this.bin, this.binDir);
  final TestEnv env;
  final String hd;
  final FolderRecycleBin bin;
  final Directory binDir;

  DedupeService get dedupe => env.core.dedupe;
  File file(String rel) => File(p.join(env.volumeDir.path, 'HD', rel));

  static final a = bytes(1, 6000);
  static final b = bytes(2, 9000);

  static Future<Scenario> create() async {
    final binDir = Directory(p.join((await createTestTemp('fotoatlas_test_lixeira_')).path, 'fotoatlas_test_bin'));
    final bin = FolderRecycleBin(binDir.path);
    final env = await TestEnv.open(tools: ExternalTools.none, recycleBin: bin);
    env
      ..write('HD/Fotos/2024/2024-07/IMG_0001.jpg', a)
      ..write('HD/Bagunca/WhatsApp/IMG_0001.jpg', a)
      ..write('HD/Bagunca/IMG_0001 (1).jpg', a)
      ..write('HD/Videos/VID_0002.mp4', b)
      ..write('HD/Backup antigo/Videos/VID_0002.mp4', b)
      ..write('HD/Fotos/unica.jpg', bytes(3, 4000))
      ..write('HD/docs/a.txt', bytes(4, 100))
      ..write('HD/docs/b.txt', bytes(4, 100))
      ..write('Outro/IMG_0001.jpg', a);
    final hd = await env.addFolder('HD', name: 'HD');
    final other = await env.addFolder('Outro', name: 'Outro HD');
    await env.scan(hd);
    await env.scan(other);
    await env.hashAll();
    return Scenario(env, hd, bin, binDir);
  }

  Future<List<DedupeGroup>> groups({KeepRule? rule}) => dedupe.groups(hd, rule: rule);

  Future<OperationView> run(DedupePreview preview) async {
    final id = await dedupe.start(preview);
    await dedupe.waitIdle();
    return (await env.core.copies.view(id))!;
  }

  Future<DedupePreview> acceptAll() async =>
      dedupe.preview(hd, [for (final g in await groups()) DedupeChoice(g.contentId, g.suggestedKeepId)]);

  List<String> recycled() => binDir.existsSync()
      ? [for (final f in binDir.listSync().whereType<File>()) p.basename(f.path).split('_').skip(2).join('_')]
      : [];
}

void main() {
  test('grupos: só o mesmo conteúdo no mesmo dispositivo, de foto/RAW/vídeo, com a sugestão organizada', () async {
    final s = await Scenario.create();
    final groups = await s.groups();
    expect(groups, hasLength(2));
    final photo = groups.singleWhere((g) => g.mediaType == 'photo');
    expect(
      photo.copies.map((c) => c.relPath),
      unorderedEquals(['Fotos/2024/2024-07/IMG_0001.jpg', 'Bagunca/WhatsApp/IMG_0001.jpg', 'Bagunca/IMG_0001 (1).jpg']),
    );
    // A outra cópia (no "Outro HD") não entra: nunca entre dispositivos.
    final keep = photo.copies.singleWhere((c) => c.instanceId == photo.suggestedKeepId);
    expect(keep.relPath, 'Fotos/2024/2024-07/IMG_0001.jpg');
    expect(photo.reason, contains('organizada por data'));
    expect(photo.reclaimableBytes, 2 * 6000);
    final video = groups.singleWhere((g) => g.mediaType == 'video');
    expect(video.copies.singleWhere((c) => c.instanceId == video.suggestedKeepId).relPath, 'Videos/VID_0002.mp4');

    final summaries = await s.dedupe.summaries();
    final hd = summaries.singleWhere((x) => x.sourceId == s.hd);
    expect((hd.groups, hd.extraFiles, hd.reclaimableBytes, hd.blocker), (2, 3, 2 * 6000 + 9000, null));
    expect(summaries.where((x) => x.name == 'Outro HD'), isEmpty);
  });

  test('regra "a mais antiga": fica a criada primeiro neste disco; a regra fica salva', () async {
    final s = await Scenario.create();
    expect(await s.dedupe.keepRule(), KeepRule.organized);
    await s.dedupe.setKeepRule(KeepRule.oldest);
    expect(await s.dedupe.keepRule(), KeepRule.oldest);
    final photo = (await s.groups()).singleWhere((g) => g.mediaType == 'photo');
    final oldest = [...photo.copies]..sort((x, y) => x.ctime!.compareTo(y.ctime!));
    expect(photo.suggestedKeepId, oldest.first.instanceId);
    expect(photo.reason, contains('mais antiga'));
    expect(KeepRule.values.map((r) => r.name), ['organized', 'oldest']);
  });

  test('prévia: nada marcado não remove nada; o que sai, quantos e o espaço; a escolhida fica', () async {
    final s = await Scenario.create();
    final empty = await s.dedupe.preview(s.hd, const []);
    expect((empty.canStart, empty.blocker), (false, 'Nenhum grupo marcado.'));

    final photo = (await s.groups()).singleWhere((g) => g.mediaType == 'photo');
    // A pessoa troca qual fica: a do WhatsApp.
    final whatsapp = photo.copies.singleWhere((c) => c.relPath.contains('WhatsApp'));
    final preview = await s.dedupe.preview(s.hd, [DedupeChoice(photo.contentId, whatsapp.instanceId)]);
    expect((preview.groups, preview.files, preview.bytes, preview.canStart), (1, 2, 12000, true));
    expect(
      preview.removals.map((r) => r.relPath),
      unorderedEquals(['Fotos/2024/2024-07/IMG_0001.jpg', 'Bagunca/IMG_0001 (1).jpg']),
    );
    expect(preview.removals.map((r) => r.keepRelPath).toSet(), {'Bagunca/WhatsApp/IMG_0001.jpg'});
    // Só a prévia: nada mudou no disco.
    expect(s.file('Fotos/2024/2024-07/IMG_0001.jpg').existsSync(), isTrue);
    expect(s.recycled(), isEmpty);

    // Cópia que não é do grupo não vale como "a que fica".
    final bogus = await s.dedupe.preview(s.hd, [DedupeChoice(photo.contentId, 999999)]);
    expect((bogus.files, bogus.skipped.length, bogus.canStart), (0, 1, false));
  });

  test('limpar: as outras cópias vão para a Lixeira, a escolhida fica, o catálogo acompanha', () async {
    final s = await Scenario.create();
    final o = await s.run(await s.acceptAll());
    expect((o.kind, o.status, o.published, o.failed), (dedupeOpKind, OpStatus.completed, 3, 0));
    expect(s.file('Fotos/2024/2024-07/IMG_0001.jpg').readAsBytesSync(), Scenario.a);
    expect(s.file('Videos/VID_0002.mp4').readAsBytesSync(), Scenario.b);
    for (final gone in [
      'Bagunca/WhatsApp/IMG_0001.jpg',
      'Bagunca/IMG_0001 (1).jpg',
      'Backup antigo/Videos/VID_0002.mp4',
    ]) {
      expect(s.file(gone).existsSync(), isFalse, reason: gone);
    }
    // O que saiu está inteiro na "Lixeira".
    expect(s.recycled(), unorderedEquals(['IMG_0001.jpg', 'IMG_0001 (1).jpg', 'VID_0002.mp4']));
    for (final f in s.binDir.listSync().whereType<File>()) {
      expect([sha(Scenario.a), sha(Scenario.b)], contains(sha(f.readAsBytesSync())));
    }
    expect(await s.groups(), isEmpty);
    expect(
      await s.env.count("SELECT COUNT(*) FROM file_instances WHERE source_id = ? AND availability = 'missing'", [s.hd]),
      3,
    );
    // Os .txt repetidos e a cópia do outro dispositivo continuam.
    expect(File(p.join(s.env.volumeDir.path, 'HD', 'docs', 'b.txt')).existsSync(), isTrue);
    expect(File(p.join(s.env.volumeDir.path, 'Outro', 'IMG_0001.jpg')).existsSync(), isTrue);

    final csv = await s.dedupe.exportCsv(o.id);
    expect(csv, startsWith('﻿# FotoAtlas — relatório da limpeza de repetidos'));
    expect(csv, contains('grupo;situação;arquivo;cópia que ficou;tamanho (bytes);sha256;motivo'));
    expect(
      csv,
      contains(
        'foi para a Lixeira;Bagunca/WhatsApp/IMG_0001.jpg;Fotos/2024/2024-07/IMG_0001.jpg;6000;${sha(Scenario.a)}',
      ),
    );
    expect(csv, contains('Foram para a Lixeira do Windows: 3 arquivo(s), 21000 bytes'));
  });

  test('arquivo alterado entre a prévia e a remoção: o grupo inteiro é pulado e avisado', () async {
    final s = await Scenario.create();
    final preview = await s.acceptAll();
    // Uma das que sairiam muda de conteúdo, com o mesmo tamanho e a mesma data
    // (só a reconferência do SHA-256 percebe).
    final changed = s.file('Bagunca/WhatsApp/IMG_0001.jpg');
    final mtime = changed.lastModifiedSync();
    changed.writeAsBytesSync([...Scenario.a]..[10] ^= 0xff);
    changed.setLastModifiedSync(mtime);
    final o = await s.run(preview);
    expect((o.status, o.published, o.failed), (OpStatus.completedWithErrors, 1, 2));
    // Nada do grupo da foto saiu; o do vídeo saiu.
    expect(s.file('Bagunca/WhatsApp/IMG_0001.jpg').existsSync(), isTrue);
    expect(s.file('Bagunca/IMG_0001 (1).jpg').existsSync(), isTrue);
    expect(s.file('Backup antigo/Videos/VID_0002.mp4').existsSync(), isFalse);
    final failed = await s.env.core.copies.items(o.id, states: {'failed'});
    expect(
      failed.map((i) => i.errorMessage),
      everyElement(startsWith('Grupo pulado: "Bagunca › WhatsApp › IMG_0001.jpg" mudou')),
    );
  });

  test('a cópia que fica mudou ou sumiu: o grupo é pulado e nada dele sai', () async {
    final s = await Scenario.create();
    final preview = await s.acceptAll();
    s.file('Fotos/2024/2024-07/IMG_0001.jpg').writeAsBytesSync(bytes(9, 6000));
    s.file('Videos/VID_0002.mp4').deleteSync();
    final o = await s.run(preview);
    expect((o.published, o.failed), (0, 3));
    expect(s.recycled(), isEmpty);
    expect(s.file('Bagunca/WhatsApp/IMG_0001.jpg').existsSync(), isTrue);
    expect(s.file('Backup antigo/Videos/VID_0002.mp4').existsSync(), isTrue);
    final messages = (await s.env.core.copies.items(o.id)).map((i) => i.errorMessage).toSet();
    expect(messages, {
      contains('A cópia que ia ficar ("Fotos › 2024 › 2024-07 › IMG_0001.jpg") mudou'),
      contains('A cópia que ia ficar ("Videos › VID_0002.mp4") não está mais lá'),
    });
  });

  test('disco sem Lixeira: nada é removido e todos os grupos ficam com o motivo', () async {
    final s = await Scenario.create();
    s.bin.refuseAll = true;
    final o = await s.run(await s.acceptAll());
    expect((o.published, o.failed), (0, 3));
    expect(s.recycled(), isEmpty);
    for (final rel in [
      'Bagunca/WhatsApp/IMG_0001.jpg',
      'Bagunca/IMG_0001 (1).jpg',
      'Backup antigo/Videos/VID_0002.mp4',
    ]) {
      expect(s.file(rel).existsSync(), isTrue);
    }
    expect((await s.env.core.copies.items(o.id)).map((i) => i.errorCode).toSet(), {'no_recycle_bin'});
  });

  test('celular, pendrive, cartão, disco desconectado e sem Lixeira disponível: bloqueado com o motivo', () async {
    final s = await Scenario.create();
    final choices = [for (final g in await s.groups()) DedupeChoice(g.contentId, g.suggestedKeepId)];
    for (final (kind, text) in [
      ('usb_stick', 'Pendrive e cartão de memória não têm Lixeira'),
      ('memory_card', 'Pendrive e cartão de memória não têm Lixeira'),
      ('phone', 'nunca remove nada do celular'),
    ]) {
      await s.env.db.customStatement('UPDATE sources SET kind = ? WHERE id = ?', [kind, s.hd]);
      final preview = await s.dedupe.preview(s.hd, choices);
      expect(preview.canStart, isFalse, reason: kind);
      expect(preview.blocker, contains(text), reason: kind);
      await expectLater(s.dedupe.start(preview), throwsStateError);
    }
    await s.env.db.customStatement("UPDATE sources SET kind = 'folder' WHERE id = ?", [s.hd]);
    expect((await s.dedupe.preview(s.hd, choices)).canStart, isTrue);

    final noBin = await TestEnv.open(tools: ExternalTools.none);
    noBin.write('HD/a.jpg', Scenario.a);
    noBin.write('HD/b.jpg', Scenario.a);
    final hd = await noBin.addFolder('HD');
    await noBin.scan(hd);
    await noBin.hashAll();
    final g = (await noBin.core.dedupe.groups(hd)).single;
    final preview = await noBin.core.dedupe.preview(hd, [DedupeChoice(g.contentId, g.suggestedKeepId)]);
    expect(preview.blocker, contains('Lixeira do Windows não está disponível'));
  });

  test('a cópia que fica nunca sai, e o mesmo arquivo com outro nome não é uma cópia', () async {
    final s = await Scenario.create();
    final photo = (await s.groups()).singleWhere((g) => g.mediaType == 'photo');
    final preview = await s.dedupe.preview(s.hd, [DedupeChoice(photo.contentId, photo.suggestedKeepId)]);
    expect(preview.removals.map((r) => r.instanceId), isNot(contains(photo.suggestedKeepId)));
    // Uma prévia adulterada que tiraria também a que fica é recusada.
    final forged = DedupePreview(
      sourceId: preview.sourceId,
      sourceName: preview.sourceName,
      groups: 1,
      removals: [
        ...preview.removals,
        DedupeRemoval(
          contentId: photo.contentId,
          instanceId: photo.suggestedKeepId,
          relPath: 'Fotos/2024/2024-07/IMG_0001.jpg',
          sizeBytes: 6000,
          mtime: null,
          keepInstanceId: photo.suggestedKeepId,
          keepRelPath: 'Fotos/2024/2024-07/IMG_0001.jpg',
        ),
      ],
    );
    await expectLater(s.dedupe.start(forged), throwsStateError);
    expect(await s.env.count('SELECT COUNT(*) FROM operations'), 0);
  });

  test('link físico (o mesmo arquivo em dois caminhos) não é removido', () async {
    final s = await Scenario.create();
    final target = s.file('Fotos/unica.jpg').path;
    final link = p.join(s.env.volumeDir.path, 'HD', 'Atalhos', 'unica.jpg');
    Directory(p.dirname(link)).createSync();
    final r = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      "New-Item -ItemType HardLink -Path '$link' -Target '$target' | Out-Null",
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    await s.env.scan(s.hd);
    await s.env.hashAll();
    final g = (await s.groups()).singleWhere((g) => g.copies.any((c) => c.relPath == 'Atalhos/unica.jpg'));
    final o = await s.run(await s.dedupe.preview(s.hd, [DedupeChoice(g.contentId, g.suggestedKeepId)]));
    expect((o.published, o.failed), (0, 1));
    expect((await s.env.core.copies.items(o.id)).single.errorCode, 'same_file');
    expect(File(target).existsSync() && File(link).existsSync(), isTrue);
  });

  test('interrompida no meio: a recuperação decide pelo disco, é idempotente e a limpeza termina', () async {
    final s = await Scenario.create();
    final o = await s.run(await s.acceptAll());
    expect(o.published, 3);
    // Simula o app fechado em dois pontos do protocolo: um arquivo com a
    // intenção gravada que ainda está lá, e outro que já tinha ido para a
    // Lixeira antes de o diário registrar.
    final items = await s.env.core.copies.items(o.id);
    final stillThere = items.firstWhere((i) => i.srcRelPath == 'Bagunca/WhatsApp/IMG_0001.jpg');
    final alreadyGone = items.firstWhere((i) => i.srcRelPath == 'Backup antigo/Videos/VID_0002.mp4');
    final back = s.binDir.listSync().whereType<File>().firstWhere((f) => f.path.endsWith('_IMG_0001.jpg'));
    back.renameSync(s.file('Bagunca/WhatsApp/IMG_0001.jpg').path);
    await s.env.db.customStatement("UPDATE operation_items SET state = 'publishing' WHERE id IN (?, ?)", [
      stillThere.id,
      alreadyGone.id,
    ]);
    await s.env.db.customStatement("UPDATE operations SET status = 'running' WHERE id = ?", [o.id]);
    await s.env.db.customStatement(
      "UPDATE file_instances SET availability = 'present', missing_confirmed_at = NULL WHERE source_id = ? AND rel_path = ?",
      [s.hd, stillThere.srcRelPath],
    );
    await s.env.reopen();
    final after = (await s.env.core.copies.view(o.id))!;
    expect((after.status, after.published, after.remaining), (OpStatus.paused, 2, 1));
    // Rodar de novo não muda nada.
    for (var i = 0; i < 2; i++) {
      final report = await s.env.core.dedupe.recoverAll();
      expect(report.examined, 0);
    }
    await s.env.core.dedupe.resume(o.id);
    await s.env.core.dedupe.waitIdle();
    final done = (await s.env.core.copies.view(o.id))!;
    expect((done.status, done.published, done.failed), (OpStatus.completed, 3, 0));
    expect(s.file('Bagunca/WhatsApp/IMG_0001.jpg').existsSync(), isFalse);
    expect(s.file('Fotos/2024/2024-07/IMG_0001.jpg').readAsBytesSync(), Scenario.a);
  });
}
