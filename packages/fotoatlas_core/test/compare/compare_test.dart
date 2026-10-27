import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 17 + seed * 53) & 0xff);

/// Cenário do requisito (spec §16, Fase 2): A = pasta1 + pasta2, B = pasta3,
/// com nomes diferentes e conteúdo parcial.
///
/// | conteúdo | A (pasta1 + pasta2)                   | B (pasta3)                 |
/// |----------|---------------------------------------|----------------------------|
/// | C1 (1000)| pasta1/IMG_0001.jpg, pasta1/dup.jpg   | pasta3/foto renomeada.jpg  |
/// | C2 (2000)| pasta1/IMG_0002.jpg                   | —                          |
/// | C3 (3000)| pasta2/VID_0001.mp4                   | pasta3/sub/video.mp4       |
/// | C4 (400) | pasta2/notas.txt                      | —                          |
/// | C5 (5000)| —                                     | pasta3/extra.jpg           |
class Scenario {
  Scenario(this.env, this.hd2, this.disco1, this.disco2);
  final TestEnv env;
  final Directory hd2;
  final String disco1;
  final String disco2;

  Scope get a => Scope([ScopeEntry(disco1, 'pasta1'), ScopeEntry(disco1, 'pasta2')]);
  Scope get b => Scope([ScopeEntry(disco2, 'pasta3')]);

  static Future<Scenario> create({bool hash = true}) async {
    final env = await TestEnv.open();
    final hd2 = env.addVolume('HD2');
    env
      ..write('Disco1/pasta1/IMG_0001.jpg', bytes(1, 1000))
      ..write('Disco1/pasta1/dup.jpg', bytes(1, 1000))
      ..write('Disco1/pasta1/IMG_0002.jpg', bytes(2, 2000))
      ..write('Disco1/pasta2/VID_0001.mp4', bytes(3, 3000))
      ..write('Disco1/pasta2/notas.txt', bytes(4, 400))
      // Fora dos escopos: não pode influenciar.
      ..write('Disco1/outra/IMG_0002.jpg', bytes(2, 2000))
      ..write('Disco2/pasta3/foto renomeada.jpg', bytes(1, 1000), volume: hd2)
      ..write('Disco2/pasta3/sub/video.mp4', bytes(3, 3000), volume: hd2)
      ..write('Disco2/pasta3/extra.jpg', bytes(5, 5000), volume: hd2)
      ..write('Disco2/fora/notas.txt', bytes(4, 400), volume: hd2);
    final d1 = await env.addFolder('Disco1');
    final d2 = await env.addFolder('Disco2', volume: hd2);
    await env.scan(d1);
    await env.scan(d2);
    if (hash) await env.hashAll();
    return Scenario(env, hd2, d1, d2);
  }

  Future<CompareSummary> compare([Scope? a, Scope? b]) => env.core.compare.compare(a ?? this.a, b ?? this.b);
}

void main() {
  test('A = pasta1 + pasta2, B = pasta3: faltam, só em B e nos dois, por conteúdo', () async {
    final s = await Scenario.create();
    final r = await s.compare();

    expect(r.verdict, CompareVerdict.missing);
    expect(r.issues, isEmpty);
    expect(r.aFiles, 5);
    expect(r.bFiles, 3);
    // Faltam C2 e C4 (o IMG_0002 de "outra/" está fora do escopo B).
    expect(r.missing.contents, 2);
    expect(r.missing.bytes, 2000 + 400);
    expect(r.missing.files, 2);
    // Só em B: C5.
    expect(r.onlyInB.contents, 1);
    expect(r.onlyInB.bytes, 5000);
    // Nos dois: C1 (2 arquivos em A, nomes diferentes de B) e C3 (outra pasta).
    expect(r.inBoth.contents, 2);
    expect(r.inBoth.bytes, 1000 + 3000);
    expect(r.inBoth.files, 3);

    final missing = await s.env.core.compare.items(s.a, s.b, CompareList.missing);
    expect(missing.map((i) => i.relPath), ['pasta1/IMG_0002.jpg', 'pasta2/notas.txt']);
    final both = await s.env.core.compare.items(s.a, s.b, CompareList.inBoth);
    final c1 = both.firstWhere((i) => i.sizeBytes == 1000);
    expect(c1.copies, 2);
    expect(c1.otherRelPath, 'pasta3/foto renomeada.jpg');
    final onlyB = await s.env.core.compare.items(s.a, s.b, CompareList.onlyInB);
    expect(onlyB.single.relPath, 'pasta3/extra.jpg');
  });

  test('depois de copiar o que faltava (com outros nomes): "Sim, 100%"', () async {
    final s = await Scenario.create();
    s.env
      ..write('Disco2/pasta3/2024/qualquer nome.jpg', bytes(2, 2000), volume: s.hd2)
      ..write('Disco2/pasta3/docs/n.txt', bytes(4, 400), volume: s.hd2);
    await s.env.scan(s.disco2);
    await s.env.hashAll();
    final r = await s.compare();
    expect(r.verdict, CompareVerdict.complete);
    expect(r.missing.contents, 0);
    // A pergunta é direcional: B × A continua com o que só B tem.
    final inverse = await s.compare(s.b, s.a);
    expect(inverse.verdict, CompareVerdict.missing);
    expect(inverse.missing.contents, 1);
  });

  test('arquivo sem conteúdo conferido em A ou em B → "incompleto", nunca 100%', () async {
    final s = await Scenario.create(hash: false);
    var r = await s.compare();
    expect(r.verdict, CompareVerdict.incomplete);
    final a = r.issues.whereType<UnverifiedFiles>().firstWhere((u) => u.side == 'A');
    expect(a.pending, 5);
    expect(r.issues.whereType<UnverifiedFiles>().firstWhere((u) => u.side == 'B').pending, 3);

    await s.env.hashAll();
    // Tudo já está em B, exceto C2 e C4; copiamos e não conferimos ainda.
    s.env
      ..write('Disco2/pasta3/c2.jpg', bytes(2, 2000), volume: s.hd2)
      ..write('Disco2/pasta3/c4.txt', bytes(4, 400), volume: s.hd2);
    await s.env.scan(s.disco2);
    r = await s.compare();
    expect(r.verdict, CompareVerdict.incomplete, reason: 'sem conferir B não dá para dizer 100%');
    expect(r.missing.contents, 2, reason: 'o que já se sabe continua visível');
    expect(r.issues.whereType<UnverifiedFiles>().single.side, 'B');
    final pendingB = await s.env.core.compare.items(s.a, s.b, CompareList.unverifiedB);
    expect(pendingB.map((i) => i.relPath), unorderedEquals(['pasta3/c2.jpg', 'pasta3/c4.txt']));

    // "Conferir agora": prioriza os escopos e resolve.
    await s.env.core.hashes.start(priority: CompareService.priorityFor([s.a, s.b]));
    await s.env.core.hashes.waitIdle();
    r = await s.compare();
    expect(r.verdict, CompareVerdict.complete);
  });

  test('erro de leitura e pasta não lida também deixam o resultado incompleto', () async {
    final s = await Scenario.create();
    await s.env.db.customStatement(
      "UPDATE file_instances SET hash_status = 'error', content_id = NULL WHERE rel_path = 'pasta2/notas.txt'",
    );
    var r = await s.compare();
    expect(r.verdict, CompareVerdict.incomplete);
    expect(r.issues.whereType<UnverifiedFiles>().single.errors, 1);

    await s.env.core.hashes.retryFailed();
    await s.env.hashAll();
    expect((await s.compare()).verdict, CompareVerdict.missing);

    // Pasta de B com erro no último scan (permissão negada, por exemplo).
    final scanId = (await s.env.core.sources.list()).firstWhere((v) => v.id == s.disco2).lastScan!.id;
    await s.env.db.customStatement("UPDATE scans SET coverage = 'partial' WHERE id = $scanId");
    await s.env.db.customStatement(
      "INSERT INTO scan_dirs (scan_id, rel_path, status) VALUES ($scanId, 'pasta3/bloqueada', 'error')",
    );
    r = await s.compare();
    expect(r.verdict, CompareVerdict.incomplete);
    final unread = r.issues.whereType<UnreadFolders>().single;
    expect(unread.side, 'B');
    expect(unread.folders, ['pasta3/bloqueada']);
    // Erro fora do escopo não afeta.
    await s.env.db.customStatement("UPDATE scan_dirs SET rel_path = 'fora/x' WHERE rel_path = 'pasta3/bloqueada'");
    expect((await s.compare()).verdict, CompareVerdict.missing);
  });

  test('fonte nunca escaneada por completo → incompleto', () async {
    final s = await Scenario.create();
    s.env.write('Novo/a.jpg', bytes(9, 10));
    final novo = await s.env.addFolder('Novo');
    final r = await s.compare(s.a, Scope([...s.b.entries, ScopeEntry(novo)]));
    expect(r.verdict, CompareVerdict.incomplete);
    expect(r.issues.whereType<NeverScanned>().single.sourceId, novo);
  });

  test('filtro por tipo: só vídeos de A estão todos em B', () async {
    final s = await Scenario.create();
    final r = await s.compare(Scope(s.a.entries, types: {ScopeFileType.video}), s.b);
    expect(r.verdict, CompareVerdict.complete);
    expect(r.aFiles, 1);
    final photos = await s.compare(Scope(s.a.entries, types: {ScopeFileType.photo}), s.b);
    expect(photos.missing.contents, 1); // IMG_0002
  });

  test('fonte desconectada: compara pelo último scan e avisa', () async {
    final s = await Scenario.create();
    s.env.volumes.volumes = [s.env.volumes.volumes.first];
    await s.env.core.sources.refreshConnectivity();
    final r = await s.compare();
    expect(r.verdict, CompareVerdict.missing);
    expect(r.missing.contents, 2);
    expect(r.warnings.whereType<DisconnectedSource>().single.side, 'B');
  });

  test('A e B sobrepostos fisicamente geram aviso', () async {
    final s = await Scenario.create();
    final r = await s.compare(s.a, Scope([ScopeEntry(s.disco1)]));
    expect(r.verdict, CompareVerdict.complete);
    expect(r.warnings.whereType<ScopesOverlap>(), isNotEmpty);
  });

  test('A vazio não vira "100%"', () async {
    final s = await Scenario.create();
    s.env.write('Disco1/vazia/.keep', const []);
    await s.env.scan(s.disco1);
    await s.env.hashAll();
    final r = await s.compare(Scope([ScopeEntry(s.disco1, 'vazia')], types: {ScopeFileType.photo}), s.b);
    expect(r.verdict, CompareVerdict.emptyA);
  });

  test('escopo: pastas dentro de outra entrada são simplificadas; JSON ida e volta', () {
    final scope = Scope(
      [const ScopeEntry('x', 'Fotos/2020'), const ScopeEntry('x', r'Fotos\'), const ScopeEntry('y')],
      types: {ScopeFileType.photo, ScopeFileType.video},
    );
    expect(scope.entries, [const ScopeEntry('x', 'Fotos'), const ScopeEntry('y')]);
    final back = Scope.fromJson(scope.toJson());
    expect(back.entries, scope.entries);
    expect(back.types, {ScopeFileType.photo, ScopeFileType.video});
    expect(Scope([const ScopeEntry('x')], types: ScopeFileType.values.toSet()).types, isNull);
  });

  test('pastas para o seletor de escopo vêm do catálogo (funciona desconectado)', () async {
    final s = await Scenario.create(hash: false);
    final sources = s.env.core.sources;
    expect(await sources.childFolders(s.disco1), ['outra', 'pasta1', 'pasta2']);
    expect(await sources.childFolders(s.disco2, 'pasta3'), ['pasta3/sub']);
    s.env.volumes.volumes = [s.env.volumes.volumes.first];
    await sources.refreshConnectivity();
    expect(await sources.childFolders(s.disco2), ['fora', 'pasta3']);
  });

  test('escopos salvos com nome: salvar, reutilizar, renomear e remover', () async {
    final s = await Scenario.create();
    final compare = s.env.core.compare;
    final saved = await compare.saveScope('Fotos do celular antigo', s.a);
    expect((await compare.savedScopes()).single.name, 'Fotos do celular antigo');
    await expectLater(compare.saveScope('fotos do celular ANTIGO', s.b), throwsA(isA<SourceException>()));
    await expectLater(compare.saveScope('Vazio', Scope(const [])), throwsA(isA<SourceException>()));

    // Reutilizar: o escopo salvo dá o mesmo resultado.
    final reused = (await compare.savedScopes()).single.scope;
    expect((await s.compare(reused, s.b)).missing.contents, 2);

    await compare.saveScope('Fotos do celular antigo', s.b, replace: true);
    expect((await compare.savedScopes()).single.scope.entries, s.b.entries);
    await compare.renameScope(saved.id, 'HD antigo');
    expect((await compare.savedScopes()).single.name, 'HD antigo');
    await compare.removeScope(saved.id);
    expect(await compare.savedScopes(), isEmpty);
    // Nada no disco mudou: os arquivos continuam lá.
    expect(await s.env.count('SELECT COUNT(*) FROM file_instances'), 10);
  });
}
