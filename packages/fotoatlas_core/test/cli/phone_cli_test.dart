@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart' show HelperClient;
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

import '../support/temp.dart';

/// Celular ponta a ponta: CLI compilada + helper real (.NET) com celulares
/// simulados (`--fake-devices`). Nenhum aparelho real é tocado.
void main() {
  final helper = HelperClient.locate();
  // Na CI o helper é compilado antes: faltar lá é erro, não "pular".
  final skip = helper == null && Platform.environment['CI'] == null
      ? 'helper não compilado (dotnet build em native/fotoatlas_helper)'
      : false;
  late Directory buildDir;
  late String cli;

  setUpAll(() async {
    if (helper == null) {
      if (Platform.environment['CI'] != null) fail('helper não encontrado na CI');
      return;
    }
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_phone_build_');
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
    if (helper == null) return;
    assertInTemp(buildDir.path);
    await buildDir.delete(recursive: true);
  });

  Map<String, String> env(PhoneDemo demo, [Map<String, String> extra = const {}]) => {
    'FOTOATLAS_HELPER': helper!,
    'FOTOATLAS_FAKE_DEVICES': demo.devicesDir,
    ...extra,
  };

  Future<ProcessResult> run(String home, PhoneDemo demo, List<String> args, {Map<String, String> extra = const {}}) =>
      Process.run(
        cli,
        ['--home', home, ...args],
        environment: env(demo, extra),
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  Future<void> ok(Future<ProcessResult> call, [Matcher? out]) async {
    final r = await call;
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    if (out != null) expect(r.stdout as String, out);
  }

  int scalar(String home, String sql) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      return db.select(sql).first.values.first as int;
    } finally {
      db.close();
    }
  }

  test('celular × HD pela CLI: listar, cadastrar, escanear, conferir e comparar', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final demo = generatePhoneDemo(p.join(temp.path, 'demo'));

    final devices = await run(home, demo, ['devices']);
    expect(devices.exitCode, 0, reason: '${devices.stdout}${devices.stderr}');
    final out = devices.stdout as String;
    expect(out, contains('Pixel de Teste  [pronto]  android (simulado)'));
    expect(out, contains('iPhone de Teste  [sem autorização]'));
    expect(out, contains('Confiar'));
    expect(out, contains('Manter originais'));

    await ok(run(home, demo, ['sources', 'add-phone', 'Pixel de Teste', '--name', 'Pixel']), contains('SOURCE '));
    await ok(run(home, demo, ['sources', 'add', demo.hdDir, '--name', 'HD']));
    await ok(run(home, demo, ['scan', 'start', 'Pixel']), contains('completed arquivos=6 '));
    await ok(run(home, demo, ['scan', 'start', 'HD']), contains('completed arquivos=4 '));
    await ok(run(home, demo, ['hash', 'run']));
    expect(scalar(home, "SELECT COUNT(*) FROM file_instances WHERE hash_status != 'done'"), 0);

    final compare = await run(home, demo, ['compare', 'Pixel', 'HD']);
    expect(compare.exitCode, 0, reason: '${compare.stdout}${compare.stderr}');
    expect(compare.stdout as String, contains('VERDICT missing'));
    expect(compare.stdout as String, contains('MISSING contents=3 '));
    expect(compare.stdout as String, contains('ONLY_B contents=1 '));
    expect(compare.stdout as String, contains('BOTH contents=3 '));

    // Sem o celular: continua listado com os dados do último scan (regra 9).
    File(demo.pixelJson).renameSync('${demo.pixelJson}.off');
    await ok(run(home, demo, ['sources', 'list']), contains('[desconectada]'));
    final again = await run(home, demo, ['compare', 'Pixel', 'HD']);
    expect(again.stdout as String, contains('MISSING contents=3 '));
  }, skip: skip);

  test('desconexão no meio do scan do celular: catálogo íntegro, nada ausente, retoma', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final demo = generatePhoneDemo(p.join(temp.path, 'demo'), pixelFaults: {'disconnectAfterListCalls': 7});
    await ok(run(home, demo, ['sources', 'add-phone', 'Pixel de Teste', '--name', 'Pixel']));
    final cut = await run(home, demo, ['scan', 'start', 'Pixel']);
    expect(cut.stdout as String, contains('interrupted'), reason: '${cut.stdout}${cut.stderr}');
    expect(cut.stdout as String, contains('desconectado'));
    expect(scalar(home, "SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    expect(db.select('PRAGMA integrity_check').first.values.first, 'ok');
    db.close();

    // Outro processo = helper novo = "reconectado" (e com IDs de objeto novos).
    var resumed = await run(home, demo, ['scan', 'start', 'Pixel']);
    for (var i = 0; i < 5 && (resumed.stdout as String).contains('interrupted'); i++) {
      resumed = await run(home, demo, ['scan', 'start', 'Pixel']);
    }
    expect(resumed.stdout as String, contains('completed arquivos=6 '), reason: '${resumed.stdout}${resumed.stderr}');
    expect(scalar(home, 'SELECT COUNT(*) FROM file_instances'), 6);
    expect(scalar(home, "SELECT COUNT(*) FROM scans WHERE status = 'completed' AND coverage = 'complete'"), 1);
  }, skip: skip);

  test('kill no meio do scan do celular → retomar sem duplicar', () async {
    final temp = await createTestTemp();
    final home = p.join(temp.path, 'home');
    final demo = generatePhoneDemo(p.join(temp.path, 'demo'));
    await ok(run(home, demo, ['sources', 'add-phone', 'Pixel de Teste', '--name', 'Pixel']));

    final process = await Process.start(cli, [
      '--home',
      home,
      'scan',
      'start',
      'Pixel',
    ], environment: env(demo, {'FOTOATLAS_CRASHPOINT': 'scan.after_batch_commit:4'}));
    final hit = Completer<void>();
    process.stdout.transform(utf8.decoder).listen((s) {
      if (s.contains('CRASHPOINT') && !hit.isCompleted) hit.complete();
    });
    process.stderr.drain<void>().ignore();
    await hit.future.timeout(const Duration(seconds: 60));
    process.kill(ProcessSignal.sigkill);
    await process.exitCode;
    final partial = scalar(home, 'SELECT COUNT(*) FROM file_instances');
    expect(partial, lessThan(6));

    await ok(run(home, demo, ['scan', 'start', 'Pixel']), contains('completed arquivos=6 '));
    expect(scalar(home, 'SELECT COUNT(*) FROM file_instances'), 6);
    expect(scalar(home, "SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  }, skip: skip);
}
