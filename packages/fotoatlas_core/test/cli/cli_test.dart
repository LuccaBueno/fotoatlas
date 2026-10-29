@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';

/// Testes de integração e de falha pela CLI compilada (ADR 0007).
void main() {
  late Directory buildDir;
  late String cli;

  setUpAll(() async {
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_build_');
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

  Future<ProcessResult> run(String home, List<String> args, {Map<String, String>? env}) => Process.run(
    cli,
    ['--home', home, '--no-helper', ...args],
    environment: env,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  test('cadastrar, escanear e listar pela CLI', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final manifest = generateTree(p.join(temp.path, 'Fotos'), const FixtureOptions(files: 500));

    final add = await run(home, ['sources', 'add', p.join(temp.path, 'Fotos'), '--name', 'Fotos']);
    expect(add.exitCode, 0, reason: '${add.stdout}${add.stderr}');
    expect(add.stdout as String, contains('SOURCE '));

    final scan = await run(home, ['scan', 'start', 'Fotos']);
    expect(scan.exitCode, 0, reason: '${scan.stdout}${scan.stderr}');
    expect(scan.stdout as String, contains('completed arquivos=${manifest.files} '));

    final list = await run(home, ['sources', 'list']);
    expect(list.stdout as String, contains('[conectada]'));
    expect(list.stdout as String, contains('${manifest.files} arquivos'));

    final volumes = await run(home, ['volumes', '--json']);
    expect(volumes.exitCode, 0);
    final parsed = jsonDecode(volumes.stdout as String) as List<Object?>;
    expect(parsed.where((v) => (v as Map)['isBoot'] == true), hasLength(1));
  });

  test('segundo processo no mesmo catálogo é recusado', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    Directory(p.join(temp.path, 'Fotos')).createSync();
    File(p.join(temp.path, 'Fotos', 'a.jpg')).writeAsBytesSync([1]);
    await run(home, ['sources', 'add', p.join(temp.path, 'Fotos'), '--name', 'Fotos']);

    // Um processo fica parado num crashpoint segurando o catálogo.
    final holder = await Process.start(
      cli,
      ['--home', home, '--no-helper', 'scan', 'start', 'Fotos'],
      environment: {'FOTOATLAS_CRASHPOINT': 'scan.after_batch_commit:1'},
    );
    await holder.stdout.transform(utf8.decoder).firstWhere((l) => l.contains('CRASHPOINT'));
    final second = await run(home, ['sources', 'list']);
    holder.kill();
    await holder.exitCode;
    expect(second.exitCode, 1);
    expect(second.stderr as String, contains('já está em uso'));
  });

  test('comparar pela CLI: A = pasta1 + pasta2, B = pasta3, e escopo salvo', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    void write(String rel, List<int> bytes) {
      final f = File(p.join(temp.path, rel));
      f.parent.createSync(recursive: true);
      f.writeAsBytesSync(bytes);
    }

    write('Disco/pasta1/IMG_1.jpg', List.filled(1000, 1));
    write('Disco/pasta1/IMG_2.jpg', List.filled(2000, 2));
    write('Disco/pasta2/VID_1.mp4', List.filled(3000, 3));
    write('Backup/pasta3/renomeada.jpg', List.filled(1000, 1));
    write('Backup/pasta3/x/video.mp4', List.filled(3000, 3));
    write('Backup/pasta3/so_b.jpg', List.filled(500, 9));
    for (final (dir, name) in [('Disco', 'Disco'), ('Backup', 'Backup')]) {
      expect((await run(home, ['sources', 'add', p.join(temp.path, dir), '--name', name])).exitCode, 0);
      expect((await run(home, ['scan', 'start', name])).exitCode, 0);
    }

    var r = await run(home, ['compare', 'Disco:pasta1+Disco:pasta2', 'Backup:pasta3']);
    expect(r.stdout as String, contains('VERDICT incomplete'), reason: 'ainda sem conferir o conteúdo');

    final hash = await run(home, ['hash', 'run']);
    expect(hash.stdout as String, contains('HASH done feitos=6 erros=0'), reason: '${hash.stdout}${hash.stderr}');

    expect((await run(home, ['scopes', 'save', 'Fotos do celular antigo', 'Disco:pasta1+Disco:pasta2'])).exitCode, 0);
    r = await run(home, ['compare', '@Fotos do celular antigo', 'Backup:pasta3', '--list', 'missing']);
    final out = r.stdout as String;
    expect(out, contains('Falta 1 arquivo (2.0 KB) de A em B.'));
    expect(out, contains('VERDICT missing'));
    expect(out, contains('MISSING contents=1 bytes=2000 files=1'));
    expect(out, contains('ONLY_B contents=1 bytes=500'));
    expect(out, contains('BOTH contents=2 bytes=4000'));
    expect(out, contains('ITEM Disco:pasta1/IMG_2.jpg'));
  });

  test('processo morto no meio da conferência: retomar termina sem duplicar conteúdo', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final manifest = generateTree(p.join(temp.path, 'Fotos'), const FixtureOptions(files: 300, seed: 7));
    expect((await run(home, ['sources', 'add', p.join(temp.path, 'Fotos'), '--name', 'Fotos'])).exitCode, 0);
    expect((await run(home, ['scan', 'start', 'Fotos'])).exitCode, 0);

    final victim = await Process.start(
      cli,
      ['--home', home, '--no-helper', 'hash', 'run'],
      environment: {'FOTOATLAS_CRASHPOINT': 'hash.after_batch_commit:2'},
    );
    final output = StringBuffer();
    final reached = Completer<void>();
    victim.stdout.transform(utf8.decoder).listen((chunk) {
      output.write(chunk);
      if (output.toString().contains('CRASHPOINT hash.after_batch_commit') && !reached.isCompleted) {
        reached.complete();
      }
    });
    victim.stderr.drain<void>().ignore();
    await reached.future.timeout(const Duration(minutes: 2), onTimeout: () => fail('crashpoint não atingido: $output'));
    expect(victim.kill(), isTrue);
    await victim.exitCode;

    final resumed = await run(home, ['hash', 'run']);
    expect(resumed.exitCode, 0, reason: '${resumed.stdout}${resumed.stderr}');
    // 2 lotes de 32 já estavam gravados; o resto foi feito agora.
    expect(resumed.stdout as String, contains('HASH done feitos=${manifest.files - 64} erros=0'));
    final again = await run(home, ['hash', 'run']);
    expect(again.stdout as String, contains('HASH done feitos=0'), reason: 'nada pendente: idempotente');
    final coverage = await run(home, ['coverage']);
    expect(coverage.stdout as String, contains('Ainda sem conteúdo conferido: 0'));
  }, timeout: const Timeout(Duration(minutes: 5)));

  for (final hit in [1, 3]) {
    test('processo morto no meio do scan (lote $hit): retomar dá contagem exata', () async {
      final temp = await createTestTemp();
      final home = p.join(temp.path, 'home');
      final manifest = generateTree(p.join(temp.path, "Fotos"), FixtureOptions(files: 9000, seed: hit));
      expect((await run(home, ['sources', 'add', p.join(temp.path, 'Fotos'), '--name', 'Fotos'])).exitCode, 0);

      final victim = await Process.start(
        cli,
        ['--home', home, '--no-helper', 'scan', 'start', 'Fotos'],
        environment: {'FOTOATLAS_CRASHPOINT': 'scan.after_batch_commit:$hit'},
      );
      final output = StringBuffer();
      final reached = Completer<void>();
      victim.stdout.transform(utf8.decoder).listen((chunk) {
        output.write(chunk);
        if (output.toString().contains('CRASHPOINT scan.after_batch_commit') && !reached.isCompleted) {
          reached.complete();
        }
      });
      victim.stderr.drain<void>().ignore();
      await reached.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => fail('crashpoint não atingido: $output'),
      );
      expect(victim.kill(), isTrue, reason: 'TerminateProcess');
      await victim.exitCode;

      final status = await run(home, ['scan', 'status']);
      expect(status.stdout as String, contains('interrupted'), reason: 'o scan morto fica retomável');

      final resumed = await run(home, ['scan', 'start', 'Fotos']);
      expect(resumed.exitCode, 0, reason: '${resumed.stdout}${resumed.stderr}');
      expect(resumed.stdout as String, contains('completed arquivos=${manifest.files} '));

      final list = await run(home, ['sources', 'list']);
      expect(list.stdout as String, contains('${manifest.files} arquivos'), reason: 'sem duplicatas nem perdas');
      expect(RegExp('#').allMatches(status.stdout as String), hasLength(1), reason: 'o mesmo scan foi retomado');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}
