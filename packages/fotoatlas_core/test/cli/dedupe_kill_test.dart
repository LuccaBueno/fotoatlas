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

/// Testes de falha do "Limpar repetidos" (ADR 0007 e 0027): a CLI compilada é
/// morta em cada ponto do protocolo (depois da reconferência, com a intenção
/// gravada, logo depois de o arquivo ir para a Lixeira e depois do registro)
/// e no meio da própria recuperação. A recuperação roda 3 vezes sem efeito
/// colateral; depois a limpeza continua e termina. Em nenhum momento um
/// conteúdo deixa de existir: o que saiu do HD está inteiro na "Lixeira" (uma
/// pasta de teste, `--test-recycle-dir`) e a cópia que fica nunca sai.
void main() {
  late Directory buildDir;
  late String cli;

  setUpAll(() async {
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_dedupe_build_');
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

  List<String> base(String home, String bin) => ['--home', home, '--no-helper', '--test-recycle-dir', bin];

  Future<ProcessResult> run(String home, String bin, List<String> args) =>
      Process.run(cli, [...base(home, bin), ...args], stdoutEncoding: utf8, stderrEncoding: utf8);

  Future<void> runUntilCrash(String home, String bin, List<String> args, String crashpoint) async {
    final proc = await Process.start(
      cli,
      [...base(home, bin), ...args],
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

  String snapshot(String home, Directory hd, Directory bin) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      return [
        for (final r in db.select(
          'SELECT seq, state, last_error_code, expected_mtime, updated_at FROM operation_items ORDER BY seq',
        ))
          r.values.join(','),
        'events=${db.select('SELECT COUNT(*) AS n FROM operation_events').first['n']}',
        for (final r in db.select('SELECT kind, status, summary_json FROM operations')) r.values.join(','),
        for (final r in db.select('SELECT id, rel_path, availability FROM file_instances ORDER BY id'))
          r.values.join(','),
        for (final e in (files(hd).entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) '${e.key}=${e.value}',
        'lixeira=${(files(bin).values.toList()..sort()).join(',')}',
      ].join('\n');
    } finally {
      db.close();
    }
  }

  final a = bytes(1, 150 * 1024), b = bytes(2, 90 * 1024), c = bytes(3, 40 * 1024);
  final kept = {'Fotos/2024/a.jpg': sha(a), 'Fotos/2024/b.jpg': sha(b), 'Fotos/c.jpg': sha(c)};

  Future<(String, Directory, Directory, List<String>)> setUpCatalog(Directory temp) async {
    final home = p.join(temp.path, 'home');
    final hd = Directory(p.join(temp.path, 'HD'));
    final bin = Directory(p.join(temp.path, 'fotoatlas_test_bin'));
    void write(String rel, List<int> data) =>
        (File(p.join(hd.path, rel))..parent.createSync(recursive: true)).writeAsBytesSync(data);
    write('Fotos/2024/a.jpg', a);
    write('Bagunca/a.jpg', a);
    write('Bagunca/a (1).jpg', a);
    write('Fotos/2024/b.jpg', b);
    write('Bagunca/b.jpg', b);
    write('Fotos/c.jpg', c);
    for (final args in [
      ['sources', 'add', hd.path, '--name', 'HD'],
      ['scan', 'start', 'HD'],
      ['hash', 'run'],
    ]) {
      final r = await run(home, bin.path, args);
      expect(r.exitCode, 0, reason: '$args\n${r.stdout}${r.stderr}');
    }
    final before = [...files(hd).values]..sort();
    return (home, hd, bin, before);
  }

  const dedupeArgs = ['dedupe', 'start', 'HD', '--all', '--yes'];

  /// Nenhum conteúdo some: HD + Lixeira têm exatamente o que o HD tinha, e
  /// cada conteúdo continua pelo menos uma vez no HD.
  void expectNothingLost(Directory hd, Directory bin, List<String> before) {
    expect([...files(hd).values, ...files(bin).values]..sort(), before);
    expect(files(hd).values.toSet(), kept.values.toSet());
    for (final e in kept.entries) {
      expect(files(hd)[e.key], e.value, reason: 'a cópia que fica (${e.key}) nunca sai');
    }
  }

  Future<void> recoverThreeTimes(String home, Directory hd, Directory bin, List<String> before) async {
    final snapshots = <String>[];
    for (var i = 0; i < 3; i++) {
      final r = await run(home, bin.path, ['recover']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      expect(r.stdout as String, contains('RECOVER_DEDUPE examinados=0'), reason: 'rodada ${i + 1}: ${r.stdout}');
      snapshots.add(snapshot(home, hd, bin));
      expectNothingLost(hd, bin, before);
    }
    expect(snapshots[1], snapshots[0], reason: 'a 2ª recuperação não pode mudar nada');
    expect(snapshots[2], snapshots[0], reason: 'a 3ª recuperação não pode mudar nada');
  }

  String operation(String home) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      return db.select("SELECT id FROM operations WHERE kind = 'dedupe_trash'").single['id'] as String;
    } finally {
      db.close();
    }
  }

  /// Prova de que o processo morreu no estado pretendido.
  void expectCrashState(String home, Directory hd, String point) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final open = db.select("SELECT src_rel_path FROM operation_items WHERE state = 'publishing'");
      if (point.startsWith('dedupe.after_check') || point.startsWith('dedupe.after_published_commit')) {
        expect(open, isEmpty);
        return;
      }
      expect(open, hasLength(1), reason: 'um arquivo no meio do protocolo');
      final src = File(p.join(hd.path, open.single['src_rel_path'] as String));
      expect(src.existsSync(), !point.startsWith('dedupe.after_recycle'));
    } finally {
      db.close();
    }
  }

  Future<void> finish(String home, Directory hd, Directory bin, List<String> before) async {
    final op = operation(home);
    final r = await run(home, bin.path, ['dedupe', 'resume', op]);
    expect(r.stdout as String, contains('DEDUPE $op completed lixeira=3 ficaram=0'), reason: '${r.stdout}${r.stderr}');
    expect(files(hd), kept);
    expect(files(bin).values.toList()..sort(), ([sha(a), sha(a), sha(b)]..sort()));
    expectNothingLost(hd, bin, before);
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final present = db
          .select("SELECT rel_path FROM file_instances WHERE availability = 'present' ORDER BY rel_path")
          .map((r) => r['rel_path']);
      expect(present, kept.keys.toList()..sort());
    } finally {
      db.close();
    }
  }

  for (final point in [
    'dedupe.after_check:1',
    'dedupe.after_publishing_commit:2',
    'dedupe.after_recycle:1',
    'dedupe.after_recycle:3',
    'dedupe.after_published_commit:2',
  ]) {
    test('limpeza morta em $point: recuperação 3× sem efeito colateral, nada perdido, e termina', () async {
      final temp = await createTestTemp();
      final (home, hd, bin, before) = await setUpCatalog(temp);
      await runUntilCrash(home, bin.path, dedupeArgs, point);
      expectCrashState(home, hd, point);
      expectNothingLost(hd, bin, before);
      await recoverThreeTimes(home, hd, bin, before);
      await finish(home, hd, bin, before);
    });
  }

  test('morta no meio da própria recuperação: a próxima termina o trabalho', () async {
    final temp = await createTestTemp();
    final (home, hd, bin, before) = await setUpCatalog(temp);
    await runUntilCrash(home, bin.path, dedupeArgs, 'dedupe.after_recycle:2');
    await runUntilCrash(home, bin.path, ['recover'], 'dedupe.recover.after_operation');
    await recoverThreeTimes(home, hd, bin, before);
    await finish(home, hd, bin, before);
  });

  test('prévia pela CLI: nada marcado sem --all; plan não toca em nada', () async {
    final temp = await createTestTemp();
    final (home, hd, bin, before) = await setUpCatalog(temp);
    final none = await run(home, bin.path, ['dedupe', 'plan', 'HD']);
    expect(none.stdout as String, contains('PREVIEW grupos=0 arquivos=0'));
    final all = await run(home, bin.path, ['dedupe', 'plan', 'HD', '--all']);
    expect(all.stdout as String, contains('PREVIEW grupos=2 arquivos=3 bytes=${2 * a.length + b.length}'));
    final noYes = await run(home, bin.path, ['dedupe', 'start', 'HD', '--all']);
    expect(noYes.exitCode, 2);
    expect([...files(hd).values]..sort(), before);
    expect(files(bin), isEmpty);
  });
}
