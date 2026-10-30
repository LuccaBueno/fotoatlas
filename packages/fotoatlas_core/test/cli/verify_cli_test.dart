@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/temp.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 11 + seed * 37 + (i >> 8)) & 0xff);

/// Conteúdo, tamanho e data de cada arquivo (prova de que nada mudou).
Map<String, String> snapshot(Directory dir) => {
  for (final f in dir.listSync(recursive: true).whereType<File>())
    p.relative(f.path, from: dir.path).replaceAll(r'\', '/'):
        '${sha256.convert(f.readAsBytesSync())} ${f.lastModifiedSync().microsecondsSinceEpoch}',
};

/// Verificação de integridade pela CLI compilada (spec §16 Fase 7): corrupção
/// com a data preservada é detectada, as outras cópias são apontadas, a
/// restauração passa pela cópia segura, e matar o processo no meio da
/// verificação não muda nenhum arquivo nem duplica resultados.
void main() {
  late Directory buildDir;
  late String cli;
  final when = DateTime.utc(2024, 5, 1, 10);

  setUpAll(() async {
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_verify_build_');
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

  Future<ProcessResult> ok(String home, List<String> args) async {
    final r = await run(home, args);
    expect(r.exitCode, 0, reason: '${args.join(' ')}\n${r.stdout}${r.stderr}');
    return r;
  }

  /// Principal com [n] fotos; Backup com as 3 primeiras (outros nomes).
  Future<(String, Directory, Directory)> setUpHome({int n = 6}) async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final main = Directory(p.join(temp.path, 'Principal'))..createSync();
    final backup = Directory(p.join(temp.path, 'Backup'))..createSync();
    for (var i = 0; i < n; i++) {
      File(p.join(main.path, 'foto$i.jpg'))
        ..writeAsBytesSync(bytes(i, 20000 + i))
        ..setLastModifiedSync(when);
      if (i < 3) {
        File(p.join(backup.path, 'copia$i.jpg'))
          ..writeAsBytesSync(bytes(i, 20000 + i))
          ..setLastModifiedSync(when);
      }
    }
    await ok(home, ['sources', 'add', main.path, '--name', 'Principal']);
    await ok(home, ['sources', 'add', backup.path, '--name', 'Backup']);
    await ok(home, ['scan', 'start', 'Principal']);
    await ok(home, ['scan', 'start', 'Backup']);
    await ok(home, ['hash', 'run']);
    return (home, main, backup);
  }

  void corrupt(File f) {
    final t = f.lastModifiedSync();
    final b = Uint8List.fromList(f.readAsBytesSync());
    b[500] ^= 0xff;
    f.writeAsBytesSync(b);
    f.setLastModifiedSync(t);
  }

  test('corrupção detectada, outras cópias apontadas e restauração pela cópia segura', () async {
    final (home, main, backup) = await setUpHome();
    corrupt(File(p.join(main.path, 'foto1.jpg')));
    final before = snapshot(main);

    final verify = await ok(home, ['verify', 'start', 'Principal']);
    expect(verify.stdout as String, contains('ESTIMATE arquivos=6 '));
    expect(verify.stdout as String, contains('completed arquivos=6/6 inalterados=5 alterados=0 corrompidos=1'));
    expect(snapshot(main), before, reason: 'verificar só lê');

    final problems = (await ok(home, ['verify', 'problems'])).stdout as String;
    final problem = RegExp(r'PROBLEM (\d+) Principal:foto1\.jpg copias=1').firstMatch(problems);
    final copy = RegExp(r'COPY (\d+) Backup:copia1\.jpg conectada=true').firstMatch(problems);
    expect(problem, isNotNull, reason: problems);
    expect(copy, isNotNull, reason: problems);

    // Sem --yes: só a prévia, nada gravado.
    final args = ['verify', 'restore', problem!.group(1)!, '--from', copy!.group(1)!];
    final preview = await run(home, args);
    expect(preview.exitCode, 2);
    expect(preview.stdout as String, contains('copia1.jpg -> foto1_1.jpg'));
    expect(snapshot(main), before);

    final restore = await ok(home, [...args, '--yes']);
    expect(restore.stdout as String, contains('publicados=1'));
    expect(File(p.join(main.path, 'foto1_1.jpg')).readAsBytesSync(), bytes(1, 20001));
    expect(snapshot(main)['foto1.jpg'], before['foto1.jpg'], reason: 'o danificado fica intacto');
  });

  test('matar o processo no meio da verificação: arquivos intactos, continua sem repetir', () async {
    final (home, main, _) = await setUpHome(n: 8);
    corrupt(File(p.join(main.path, 'foto6.jpg')));
    final before = snapshot(main);

    final proc = await Process.start(
      cli,
      ['--home', home, '--no-helper', 'verify', 'start', 'Principal'],
      environment: {'FOTOATLAS_CRASHPOINT': 'verify.after_file_commit:3'},
    );
    final output = StringBuffer();
    final reached = Completer<void>();
    proc.stdout.transform(utf8.decoder).listen((s) {
      output.write(s);
      if (output.toString().contains('CRASHPOINT verify.after_file_commit') && !reached.isCompleted) {
        reached.complete();
      }
    });
    proc.stderr.transform(utf8.decoder).listen(output.write);
    await reached.future.timeout(const Duration(seconds: 60), onTimeout: () => fail('$output'));
    proc.kill();
    await proc.exitCode;
    expect(snapshot(main), before);

    // Ao abrir de novo, a rodada fica "interrompida", com 3 arquivos feitos.
    final status = (await ok(home, ['verify', 'status'])).stdout as String;
    expect(status, contains('RUN 1 manual paused arquivos=3/8'));
    expect(status, contains('Interrompida'));

    final resume = await ok(home, ['verify', 'resume', '1']);
    expect(resume.stdout as String, contains('completed arquivos=8/8 inalterados=7 alterados=0 corrompidos=1'));
    expect(snapshot(main), before);
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final dup = db.select(
        'SELECT instance_id FROM integrity_checks WHERE run_id = 1 GROUP BY instance_id HAVING COUNT(*) > 1',
      );
      expect(dup, isEmpty);
    } finally {
      db.close();
    }
  });

  test('periódica pela CLI: liga, desliga e só lê discos', () async {
    final (home, _, _) = await setUpHome(n: 2);
    expect((await ok(home, ['verify', 'schedule'])).stdout, contains('SCHEDULE ligada=true a_cada_dias=90'));
    expect((await ok(home, ['verify', 'tick'])).stdout, contains('TICK nada a fazer'));
    await ok(home, ['verify', 'schedule', '--every', '0']);
    final tick = (await ok(home, ['verify', 'tick'])).stdout as String;
    expect(tick, contains('periodica completed arquivos=4/4 inalterados=4'));
    await ok(home, ['verify', 'schedule', 'off']);
    expect((await ok(home, ['verify', 'tick'])).stdout, contains('TICK nada a fazer'));
  });
}
