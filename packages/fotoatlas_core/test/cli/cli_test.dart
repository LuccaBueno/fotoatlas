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
  tearDownAll(() async {
    assertInTemp(buildDir.path);
    await buildDir.delete(recursive: true);
  });

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
