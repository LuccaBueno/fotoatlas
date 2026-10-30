@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/temp.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 7 + seed * 131 + (i >> 9)) & 0xff);
String sha(List<int> b) => sha256.convert(b).toString();

Map<String, String> files(Directory dir) => {
  if (dir.existsSync())
    for (final f in dir.listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: dir.path).replaceAll(r'\', '/'): sha(f.readAsBytesSync()),
};

/// Testes de falha da reorganização e do Desfazer (spec §16 Fase 6, ADR 0007
/// e 0017): a CLI compilada é morta em cada ponto do protocolo de mover (e no
/// meio da própria recuperação). A recuperação roda 3 vezes: a 1ª conserta, a
/// 2ª e a 3ª não mudam nada. Depois a operação continua e termina sem perda
/// nem sobrescrita, e o Desfazer devolve os arquivos exatamente como antes.
void main() {
  late Directory buildDir;
  late String cli;

  setUpAll(() async {
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_reorg_build_');
    final r = await Process.run(Platform.resolvedExecutable, [
      'build',
      'cli',
      '-t',
      'bin/fotoatlas_cli.dart',
      '-o',
      buildDir.path,
    ]);
    expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    cli = p.join(buildDir.path, 'bundle', 'bin', 'fotoatlas_cli.exe');
  });
  tearDownAll(() => deleteTestDir(buildDir));

  Future<ProcessResult> run(String home, List<String> args) =>
      Process.run(cli, ['--home', home, '--no-helper', ...args], stdoutEncoding: utf8, stderrEncoding: utf8);

  Future<void> runUntilCrash(String home, List<String> args, String crashpoint) async {
    final proc = await Process.start(
      cli,
      ['--home', home, '--no-helper', ...args],
      environment: {'FOTOATLAS_CRASHPOINT': crashpoint},
    );
    final output = StringBuffer();
    final reached = Completer<void>();
    proc.stdout.transform(utf8.decoder).listen((s) {
      output.write(s);
      if (output.toString().contains('CRASHPOINT ${crashpoint.split(':').first}') && !reached.isCompleted) {
        reached.complete();
      }
    });
    proc.stderr.transform(utf8.decoder).listen(output.write);
    final exited = proc.exitCode.then((code) {
      if (!reached.isCompleted) reached.completeError(StateError('saiu ($code) sem chegar ao ponto:\n$output'));
    });
    await reached.future.timeout(const Duration(seconds: 60));
    proc.kill();
    await exited;
  }

  String snapshot(String home, Directory hd) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      return [
        for (final r in db.select(
          'SELECT operation_id, seq, state, dst_rel_path_final, expected_mtime, last_error_code, updated_at '
          'FROM operation_items ORDER BY operation_id, seq',
        ))
          r.values.join(','),
        'events=${db.select('SELECT COUNT(*) AS n FROM operation_events').first['n']}',
        for (final r in db.select('SELECT kind, status, summary_json FROM operations ORDER BY created_at'))
          r.values.join(','),
        for (final r in db.select('SELECT id, rel_path, availability FROM file_instances ORDER BY id'))
          r.values.join(','),
        for (final e in (files(hd).entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) '${e.key}=${e.value}',
      ].join('\n');
    } finally {
      db.close();
    }
  }

  Future<(String, Directory, Map<String, String>)> setUpCatalog(Directory temp) async {
    final home = p.join(temp.path, 'home');
    final hd = Directory(p.join(temp.path, 'HD'));
    void write(String rel, List<int> data) =>
        (File(p.join(hd.path, rel))..parent.createSync(recursive: true)).writeAsBytesSync(data);
    write('Bagunca/fotos/IMG_0001.jpg', bytes(1, 150 * 1024));
    write('Bagunca/fotos/IMG_0002.jpg', bytes(2, 210 * 1024));
    write('Bagunca/fotos/sub/VID_0003.mp4', bytes(3, 260 * 1024));
    write('Bagunca/outras/IMG_0004.jpg', bytes(4, 120 * 1024));
    write('Bagunca/outras/notas.txt', bytes(5, 100));
    // Outro arquivo com o mesmo nome já está no destino: nunca é sobrescrito.
    write('Arrumado/fotos/IMG_0002.jpg', bytes(99, 4096));
    for (final args in [
      ['sources', 'add', hd.path, '--name', 'HD'],
      ['scan', 'start', 'HD'],
      ['hash', 'run'],
    ]) {
      final r = await run(home, args);
      expect(r.exitCode, 0, reason: '$args\n${r.stdout}${r.stderr}');
    }
    return (home, hd, files(hd));
  }

  const reorgArgs = ['reorg', 'start', 'HD:Bagunca', '--dest', 'Arrumado', '--template', '{original}', '--yes'];

  final organized = {
    'Arrumado/fotos/IMG_0001.jpg': sha(bytes(1, 150 * 1024)),
    'Arrumado/fotos/IMG_0002.jpg': sha(bytes(99, 4096)),
    'Arrumado/fotos/IMG_0002_1.jpg': sha(bytes(2, 210 * 1024)),
    'Arrumado/fotos/sub/VID_0003.mp4': sha(bytes(3, 260 * 1024)),
    'Arrumado/outras/IMG_0004.jpg': sha(bytes(4, 120 * 1024)),
    'Bagunca/outras/notas.txt': sha(bytes(5, 100)),
  };

  Future<void> recoverThreeTimes(String home, Directory hd, Map<String, String> before) async {
    final snapshots = <String>[];
    for (var i = 0; i < 3; i++) {
      final r = await run(home, ['recover']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      // A recuperação de verdade roda ao abrir; o comando roda de novo e não acha nada.
      expect(r.stdout as String, contains('RECOVER_REORG examinados=0'), reason: 'rodada ${i + 1}: ${r.stdout}');
      snapshots.add(snapshot(home, hd));
    }
    expect(snapshots[1], snapshots[0], reason: 'a 2ª recuperação não pode mudar nada');
    expect(snapshots[2], snapshots[0], reason: 'a 3ª recuperação não pode mudar nada');
    // Nenhum conteúdo perdido, duplicado ou sobrescrito.
    expect(files(hd).values.toList()..sort(), before.values.toList()..sort());
  }

  Future<String> operation(String home, String kind) async {
    final status = await run(home, ['reorg', 'status']);
    return RegExp('OPERATION (\\S+) $kind').firstMatch(status.stdout as String)!.group(1)!;
  }

  Future<void> resume(String home, String op, String kind) async {
    final r = await run(home, ['reorg', 'resume', op]);
    expect(r.stdout as String, contains('REORG $op $kind completed'), reason: '${r.stdout}${r.stderr}');
  }

  /// Prova de que o processo morreu no estado pretendido (antes de recuperar).
  void expectCrashState(String home, Directory hd, String point) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final open = db.select(
        "SELECT state, src_rel_path, dst_rel_path_final FROM operation_items WHERE state = 'publishing'",
      );
      if (point.startsWith('move.after_published_commit')) {
        expect(open, isEmpty);
        return;
      }
      expect(open, hasLength(1), reason: 'um arquivo no meio do protocolo');
      final src = File(p.join(hd.path, open.single['src_rel_path'] as String));
      final dst = File(p.join(hd.path, open.single['dst_rel_path_final'] as String));
      final moved = point.startsWith('move.after_move');
      expect(src.existsSync(), !moved);
      expect(dst.existsSync(), moved);
    } finally {
      db.close();
    }
  }

  for (final point in [
    'move.after_publishing_commit:2',
    'move.after_move:1',
    'move.after_move:3',
    'move.after_published_commit:2',
  ]) {
    test('reorganização morta em $point: recuperação 3× sem efeito colateral e termina', () async {
      final temp = await createTestTemp();
      final (home, hd, before) = await setUpCatalog(temp);
      await runUntilCrash(home, reorgArgs, point);
      expectCrashState(home, hd, point);
      await recoverThreeTimes(home, hd, before);
      final op = await operation(home, 'reorganize_move');
      await resume(home, op, 'reorganize_move');
      expect(files(hd), organized);
      // Catálogo: cada arquivo uma vez, no caminho novo.
      final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
      try {
        final paths = db.select('SELECT rel_path FROM file_instances ORDER BY rel_path').map((r) => r['rel_path']);
        expect(paths, organized.keys.toList()..sort());
      } finally {
        db.close();
      }
    });
  }

  for (final point in ['move.after_publishing_commit:1', 'move.after_move:2', 'move.after_published_commit:4']) {
    test('Desfazer morto em $point: recuperação 3× e devolve a estrutura exata', () async {
      final temp = await createTestTemp();
      final (home, hd, before) = await setUpCatalog(temp);
      final r = await run(home, reorgArgs);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(files(hd), organized);
      final op = await operation(home, 'reorganize_move');
      await runUntilCrash(home, ['reorg', 'undo', op, '--yes'], point);
      expectCrashState(home, hd, point);
      await recoverThreeTimes(home, hd, before);
      final undo = await operation(home, 'undo');
      await resume(home, undo, 'undo');
      expect(files(hd), before, reason: 'cada arquivo de volta ao lugar exato');
      // As pastas que a reorganização criou ficam (vazias) até a pessoa pedir.
      final folders = await run(home, ['reorg', 'folders', undo]);
      expect(folders.stdout as String, contains('FOLDER vazia Arrumado/outras'));
      expect(Directory(p.join(hd.path, 'Arrumado', 'outras')).existsSync(), isTrue);
    });
  }

  test('morto no meio da própria recuperação: a próxima recuperação termina o trabalho', () async {
    final temp = await createTestTemp();
    final (home, hd, before) = await setUpCatalog(temp);
    await runUntilCrash(home, reorgArgs, 'move.after_move:2');
    // A recuperação ao abrir morre depois de registrar o arquivo já movido.
    await runUntilCrash(home, ['recover'], 'move.recover.after_operation');
    await recoverThreeTimes(home, hd, before);
    final op = await operation(home, 'reorganize_move');
    await resume(home, op, 'reorganize_move');
    expect(files(hd), organized);
  });
}
