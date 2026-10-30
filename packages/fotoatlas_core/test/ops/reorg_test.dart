import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fake_devices.dart';
import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);
String sha(List<int> b) => sha256.convert(b).toString();

/// Arquivos (caminho → sha) e pastas de [dir]: a "estrutura" que o Desfazer
/// precisa devolver.
Map<String, String> tree(Directory dir) => {
  for (final e in dir.listSync(recursive: true))
    p.relative(e.path, from: dir.path).replaceAll(r'\', '/'): e is File ? sha(e.readAsBytesSync()) : '<pasta>',
};

Map<String, String> filesOnly(Directory dir) => {
  for (final e in tree(dir).entries)
    if (e.value != '<pasta>') e.key: e.value,
};

/// "HD" com fotos bagunçadas cujas datas vêm do nome (sem ExifTool): um
/// momento nomeado com caracteres inválidos, um sem nome, um que atravessa a
/// meia-noite, um arquivo sem data, um acompanhante `.xmp`, um conflito de
/// nome e um arquivo que não é foto.
class ReorgScenario {
  ReorgScenario(this.env, this.hd);
  final TestEnv env;
  final String hd;

  Directory get root => Directory(p.join(env.volumeDir.path, 'Fotos'));
  ReorgService get reorg => env.core.reorg;

  static Future<ReorgScenario> create() async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    final old = DateTime(2023, 3, 3, 3, 3);
    env
      ..write('Fotos/Desorganizado/IMG_20240713_140300.jpg', bytes(1, 3000))
      ..write('Fotos/Desorganizado/IMG_20240713_140300.xmp', bytes(2, 200))
      ..write('Fotos/Desorganizado/sub/IMG_20240713_151000.jpg', bytes(3, 4000))
      ..write('Fotos/Outros/IMG_20240820_093000.jpg', bytes(4, 5000))
      ..write('Fotos/Outros/IMG_20241231_233000.jpg', bytes(5, 1000))
      ..write('Fotos/Outros/IMG_20250101_001500.jpg', bytes(6, 1100))
      ..write('Fotos/Outros/notas.txt', bytes(7, 50))
      // Outra foto, com o mesmo nome e a mesma data, já no lugar: a de "Outros" ganha _1.
      ..write('Fotos/2024/2024-08-20 09h30/IMG_20240820_093000.jpg', bytes(8, 5100));
    env.write('Fotos/Outros/sem_data.jpg', bytes(9, 900)).setLastModifiedSync(old);
    final hd = await env.addFolder('Fotos', name: 'HD');
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final moments = await env.core.moments.list();
    final party = moments.singleWhere((m) => m.startLocal?.day == 13);
    await env.core.moments.rename(party.id, 'Aniversário: da "Ana"?..');
    return ReorgScenario(env, hd);
  }

  Future<ReorgPreview> preview({ConflictPolicy conflict = ConflictPolicy.suffix, String? template}) => reorg.preview(
    ReorgRequest(sourceId: hd, template: template ?? FolderTemplate.byMoment.pattern, conflict: conflict),
  );

  Future<OperationView> run(ReorgPreview preview) async {
    final id = await reorg.start(preview);
    await reorg.waitIdle();
    return (await env.core.copies.view(id))!;
  }

  Future<OperationView> undo(String reorgId) async {
    final id = await reorg.undo(reorgId);
    await reorg.waitIdle();
    return (await env.core.copies.view(id))!;
  }
}

void main() {
  group('modelos de pasta', () {
    final start = DateTime.utc(2024, 7, 13, 14, 3, 9);
    TemplateVars vars({String? moment, DateTime? momentStart, int? year = 2024}) => TemplateVars(
      year: year,
      month: 7,
      day: 14,
      hour: 1,
      minute: 2,
      second: 3,
      originalDir: 'DCIM',
      mediaType: 'photo',
      momentStart: momentStart,
      momentName: moment,
    );

    test('{momento}: nome, sem nome (início), fora de momentos e nomes inválidos', () {
      const t = '{ano}/{ano}-{mes}-{dia} {momento}';
      expect(
        renderFolder(t, vars(moment: 'Aniversário da Ana', momentStart: start)),
        '2024/2024-07-13 Aniversário da Ana',
      );
      expect(renderFolder(t, vars(momentStart: start)), '2024/2024-07-13 14h03');
      expect(renderFolder(t, vars()), undatedFolder, reason: 'hora a confirmar: fora de momentos');
      expect(renderFolder(t, vars(), toConfirm: r'Conferir\Depois'), 'Conferir/Depois');
      expect(
        renderFolder(t, vars(moment: 'Festa: "Ana"/Bia?..', momentStart: start)),
        '2024/2024-07-13 Festa_ _Ana__Bia_',
      );
      expect(renderFolder('{momento}', vars(moment: 'CON', momentStart: start)), '_CON');
      expect(renderFolder('{tipo}/{momento}', vars()), 'Fotos/$undatedFolder');
    });

    test('a data do momento manda (meia-noite) e as variáveis de hora usam a hora da foto', () {
      expect(
        renderFolder('{ano}-{mes}-{dia} {momento}', vars(momentStart: DateTime.utc(2024, 12, 31, 23, 30))),
        '2024-12-31 23h30',
      );
      expect(renderFolder('{ano}/{hora}h{minuto}m{segundo}s', vars()), '2024/01h02m03s');
      expect(renderFolder('{ano}/{hora}', vars(year: null)), undatedFolder);
    });
  });

  test('critério da spec: o modelo com momento gera a árvore esperada', () async {
    final s = await ReorgScenario.create();
    final preview = await s.preview();
    expect(preview.blocker, isNull);
    expect(
      {for (final m in preview.moves) m.srcRelPath: m.dstRelPath},
      {
        'Desorganizado/IMG_20240713_140300.jpg': '2024/2024-07-13 Aniversário_ da _Ana__/IMG_20240713_140300.jpg',
        'Desorganizado/IMG_20240713_140300.xmp': '2024/2024-07-13 Aniversário_ da _Ana__/IMG_20240713_140300.xmp',
        'Desorganizado/sub/IMG_20240713_151000.jpg': '2024/2024-07-13 Aniversário_ da _Ana__/IMG_20240713_151000.jpg',
        'Outros/IMG_20240820_093000.jpg': '2024/2024-08-20 09h30/IMG_20240820_093000_1.jpg',
        'Outros/IMG_20241231_233000.jpg': '2024/2024-12-31 23h30/IMG_20241231_233000.jpg',
        'Outros/IMG_20250101_001500.jpg': '2024/2024-12-31 23h30/IMG_20250101_001500.jpg',
        'Outros/sem_data.jpg': '$undatedFolder/sem_data.jpg',
      },
    );
    expect(preview.alreadyInPlace, 1);
    expect(preview.otherFiles, 1, reason: 'notas.txt fica onde está');
    expect(preview.renamedForConflict, 1);
    expect(preview.toConfirm, 1);
    expect(preview.sidecars, 1);
    // Árvore antes → depois.
    expect(preview.before.find('Desorganizado')!.becomesEmpty, isTrue);
    expect(preview.before.find('Outros')!.becomesEmpty, isFalse, reason: 'notas.txt continua lá');
    final party = preview.after.find('2024/2024-07-13 Aniversário_ da _Ana__')!;
    expect(party.count, 3);
    expect(party.isNew, isTrue);
    expect(preview.after.find('2024/2024-08-20 09h30')!.isNew, isFalse);
    expect(preview.after.find('2024/2024-08-20 09h30')!.conflicts, 1);
    expect(preview.after.totalCount, 7);
    // A prévia não mexeu em nada.
    expect(File(p.join(s.root.path, 'Desorganizado', 'IMG_20240713_140300.jpg')).existsSync(), isTrue);
    expect(await s.env.count('SELECT COUNT(*) FROM operations'), 0);
  });

  test('move no mesmo disco, atualiza o catálogo e Desfazer devolve a estrutura exata (mesmo após reabrir)', () async {
    final s = await ReorgScenario.create();
    final before = tree(s.root);
    final op = await s.run(await s.preview());
    expect(op.status, OpStatus.completed);
    expect(op.published, 7);
    final after = filesOnly(s.root);
    expect(after['2024/2024-08-20 09h30/IMG_20240820_093000_1.jpg'], before['Outros/IMG_20240820_093000.jpg']);
    expect(
      after['2024/2024-08-20 09h30/IMG_20240820_093000.jpg'],
      sha(bytes(8, 5100)),
      reason: 'o que já estava lá ficou',
    );
    expect(
      after.values.toList()..sort(),
      before.values.where((v) => v != '<pasta>').toList()..sort(),
      reason: 'os mesmos conteúdos, só em outro lugar',
    );
    expect(after.length, before.values.where((v) => v != '<pasta>').length, reason: 'nenhum arquivo a mais ou a menos');
    // Pastas que ficaram vazias continuam lá.
    expect(Directory(p.join(s.root.path, 'Desorganizado', 'sub')).existsSync(), isTrue);
    // O catálogo acompanha (mesmo id, caminho novo, conteúdo conferido).
    expect(
      await s.env.count(
        "SELECT COUNT(*) FROM file_instances WHERE rel_path = '2024/2024-12-31 23h30/IMG_20250101_001500.jpg' "
        "AND hash_status = 'done' AND availability = 'present'",
      ),
      1,
    );
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE rel_path LIKE 'Desorganizado/%'"), 0);
    // Um escaneamento novo não acha nada sumido nem novo.
    await s.env.scan(s.hd);
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);

    // Fecha e abre o app: o Desfazer vem do diário.
    await s.env.reopen();
    final check = await s.reorg.undoPreview(op.id);
    expect(check.ready, 7);
    expect([...check.changed, ...check.missing, ...check.occupied], isEmpty);
    final undo = await s.undo(op.id);
    expect(undo.status, OpStatus.completed);
    expect((await s.env.core.copies.view(op.id))!.undone, 7);
    // Arquivos idênticos aos de antes; as pastas criadas ficaram (vazias).
    expect(filesOnly(s.root), {
      for (final e in before.entries)
        if (e.value != '<pasta>') e.key: e.value,
    });
    final created = (await s.reorg.emptyFolders(undo.id)).map((f) => f.relPath).toList();
    expect(created, ['2024/2024-07-13 Aniversário_ da _Ana__', '2024/2024-12-31 23h30', undatedFolder]);
    expect(await s.reorg.removeEmptyFolders(undo.id, created), 3);
    expect(tree(s.root), before, reason: 'estrutura exata de antes, pastas incluídas');
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE rel_path LIKE 'Desorganizado/%'"), 3);
  });

  test('Desfazer: arquivo que mudou não volta sem confirmar; lugar ocupado e arquivo sumido avisam', () async {
    final s = await ReorgScenario.create();
    final op = await s.run(await s.preview());
    final moved = (await s.reorg.journal.itemsIn(op.id, {ItemState.published})).map((i) => i.dstRelPathFinal!).toList();
    String abs(String rel) => p.join(s.root.path, rel.replaceAll('/', r'\'));
    // Mudou depois da reorganização (outro programa editou a foto).
    final changed = moved.firstWhere((r) => r.endsWith('IMG_20240713_151000.jpg'));
    File(abs(changed)).writeAsBytesSync(bytes(70, 4100));
    // Sumiu.
    final gone = moved.firstWhere((r) => r.endsWith('IMG_20241231_233000.jpg'));
    File(abs(gone)).renameSync(p.join(s.env.temp.path, 'fora.jpg'));
    // O lugar antigo foi ocupado por outro arquivo.
    File(p.join(s.root.path, 'Outros', 'sem_data.jpg')).writeAsBytesSync(bytes(71, 10));

    final check = await s.reorg.undoPreview(op.id);
    expect(check.ready, 4);
    expect(check.changed, [changed]);
    expect(check.missing, [gone]);
    expect(check.occupied, ['Outros/sem_data.jpg']);

    final undo = await s.undo(op.id);
    expect(undo.status, OpStatus.needsAttention);
    final waiting = await s.reorg.journal.itemsIn(undo.id, {ItemState.needsAttention});
    expect(
      {for (final w in waiting) w.lastErrorCode: w.srcRelPath},
      {'changed_since_reorg': changed, 'name_conflict': '$undatedFolder/sem_data.jpg'},
    );
    expect(File(abs(changed)).existsSync(), isTrue, reason: 'não voltou sem a confirmação');
    final failed = await s.reorg.journal.itemsIn(undo.id, {ItemState.failed});
    expect(failed.single.lastErrorCode, 'source_missing');

    // Decisões: devolver o que mudou; deixar o outro onde está.
    await s.reorg.resolve(
      waiting.firstWhere((w) => w.lastErrorCode == 'changed_since_reorg').id,
      ReorgDecision.moveAnyway,
    );
    await s.reorg.waitIdle();
    expect(
      File(p.join(s.root.path, 'Desorganizado', 'sub', 'IMG_20240713_151000.jpg')).readAsBytesSync(),
      bytes(70, 4100),
    );
    await s.reorg.resolve(waiting.firstWhere((w) => w.lastErrorCode == 'name_conflict').id, ReorgDecision.leave);
    expect((await s.env.core.copies.view(undo.id))!.status, OpStatus.completedWithErrors);
    expect(
      File(p.join(s.root.path, 'Outros', 'sem_data.jpg')).readAsBytesSync(),
      bytes(71, 10),
      reason: 'nada sobrescrito',
    );
    expect(File(p.join(s.root.path, undatedFolder, 'sem_data.jpg')).existsSync(), isTrue);
  });

  test('antes de mover: arquivo que mudou ou sumiu desde o escaneamento não é movido', () async {
    final s = await ReorgScenario.create();
    final preview = await s.preview();
    File(p.join(s.root.path, 'Outros', 'IMG_20240820_093000.jpg')).writeAsBytesSync(bytes(40, 10));
    File(p.join(s.root.path, 'Outros', 'IMG_20241231_233000.jpg')).deleteSync();
    final op = await s.run(preview);
    expect(op.status, OpStatus.completedWithErrors);
    final failed = {
      for (final i in await s.reorg.journal.itemsIn(op.id, {ItemState.failed})) i.srcRelPath: i.lastErrorCode,
    };
    expect(failed, {
      'Outros/IMG_20240820_093000.jpg': 'source_changed',
      'Outros/IMG_20241231_233000.jpg': 'source_missing',
    });
    expect(File(p.join(s.root.path, 'Outros', 'IMG_20240820_093000.jpg')).readAsBytesSync(), bytes(40, 10));
    // Falha de leitura não é exclusão (regra 10).
    expect(await s.env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  });

  test('"perguntar": nome ocupado espera a decisão; mover com outro nome ou deixar', () async {
    final s = await ReorgScenario.create();
    final preview = await s.preview(conflict: ConflictPolicy.ask);
    expect(preview.askConflicts, 1);
    final op = await s.run(preview);
    expect(op.status, OpStatus.needsAttention);
    final item = (await s.reorg.journal.itemsIn(op.id, {ItemState.needsAttention})).single;
    expect(item.lastErrorCode, 'name_conflict');
    await s.reorg.resolve(item.id, ReorgDecision.rename);
    await s.reorg.waitIdle();
    expect(File(p.join(s.root.path, '2024', '2024-08-20 09h30', 'IMG_20240820_093000_1.jpg')).existsSync(), isTrue);
    expect((await s.env.core.copies.view(op.id))!.status, OpStatus.completed);
  });

  test('pastas vazias: listadas uma a uma, ocultos impedem, só remove as confirmadas', () async {
    final s = await ReorgScenario.create();
    // Pasta com só um arquivo oculto de sistema (fica).
    s.env.write('Fotos/Velha/IMG_20240820_100000.jpg', bytes(20, 100));
    final thumbs = s.env.write('Fotos/Velha/Thumbs.db', bytes(21, 10));
    await s.env.scan(s.hd);
    await s.env.hashAll();
    await s.env.core.metadata.start();
    await s.env.core.settleDates();
    await Process.run('attrib', ['+h', '+s', thumbs.path]);
    final op = await s.run(await s.preview());
    final folders = await s.reorg.emptyFolders(op.id);
    expect(
      {for (final f in folders) f.relPath: f.empty},
      {'Desorganizado': true, 'Desorganizado/sub': true, 'Velha': false},
    );
    // Só a subpasta foi confirmada: a de cima fica.
    expect(await s.reorg.removeEmptyFolders(op.id, ['Desorganizado/sub', 'Velha', 'Outros']), 1);
    expect(Directory(p.join(s.root.path, 'Desorganizado', 'sub')).existsSync(), isFalse);
    expect(Directory(p.join(s.root.path, 'Desorganizado')).existsSync(), isTrue);
    expect(thumbs.existsSync(), isTrue);
    // Pasta que deixou de estar vazia não é removida.
    s.env.write('Fotos/Desorganizado/novo.txt', [1]);
    expect(await s.reorg.removeEmptyFolders(op.id, ['Desorganizado']), 0);
    expect(File(p.join(s.root.path, 'Desorganizado', 'novo.txt')).existsSync(), isTrue);
  });

  test('celular nunca é reorganizado; disco desconectado e escaneamento faltando bloqueiam', () async {
    final devices = FakeDeviceBackend();
    final phone = FakePhone()..put('Interno/DCIM/Camera/IMG_1.jpg', bytes(1, 100));
    devices.phones.add(phone);
    final env = await TestEnv.open(devices: devices, tools: ExternalTools.none);
    await env.core.sources.refreshConnectivity();
    final cel = (await env.core.sources.addPhone(phone.deviceId)).sourceId;
    final r = await env.core.reorg.preview(ReorgRequest(sourceId: cel));
    expect(r.blocker, contains('Celulares não são reorganizados'));
    expect(r.canStart, isFalse);
    final hd = await env.addFolder('Nunca');
    expect((await env.core.reorg.preview(ReorgRequest(sourceId: hd))).blocker, contains('Escaneie'));
    await env.scan(hd);
    env.volumes.volumes = const [];
    await env.core.sources.refreshConnectivity();
    expect((await env.core.reorg.preview(ReorgRequest(sourceId: hd))).blocker, contains('desconectado'));
  });
}
