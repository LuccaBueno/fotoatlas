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

Map<String, String> tree(Directory dir) => {
  if (dir.existsSync())
    for (final f in dir.listSync(recursive: true).whereType<File>())
      p.relative(f.path, from: dir.path).replaceAll(r'\', '/'): sha(f.readAsBytesSync()),
};

/// Testes de falha da cópia segura (spec §16 Fase 5, ADR 0007): a CLI
/// compilada é morta (`TerminateProcess`) em cada estado do protocolo. Depois a
/// recuperação roda **3 vezes seguidas**: a 1ª conserta, a 2ª e a 3ª não mudam
/// nada. Por fim a cópia continua e termina sem perda, sem sobrescrita e com a
/// origem intacta.
void main() {
  late Directory buildDir;
  late String cli;

  setUpAll(() async {
    buildDir = await Directory.systemTemp.createTemp('fotoatlas_cli_copy_build_');
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

  Future<ProcessResult> run(String home, List<String> args, {Map<String, String>? env}) async {
    final r = await Process.run(
      cli,
      ['--home', home, '--no-helper', ...args],
      environment: env,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
    return r;
  }

  /// Roda até o ponto de falha e mata o processo ali.
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

  /// Diário + catálogo do destino + disco, para comparar entre recuperações.
  String snapshot(String home, Directory dest) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final items = db.select(
        'SELECT seq, state, dst_rel_path_final, tmp_rel_path, hex(src_sha256), hex(dst_sha256), attempts, '
        'last_error_code, updated_at FROM operation_items ORDER BY seq',
      );
      final events = db.select('SELECT COUNT(*) AS n FROM operation_events').first['n'];
      final ops = db.select('SELECT status, summary_json FROM operations');
      final instances = db.select(
        'SELECT rel_path, content_id, hash_status FROM file_instances '
        'WHERE source_id = (SELECT dest_source_id FROM operations) ORDER BY rel_path',
      );
      return [
        for (final r in items) r.values.join(','),
        'events=$events',
        for (final r in ops) r.values.join(','),
        for (final r in instances) r.values.join(','),
        for (final e in (tree(dest).entries.toList()..sort((a, b) => a.key.compareTo(b.key)))) '${e.key}=${e.value}',
      ].join('\n');
    } finally {
      db.close();
    }
  }

  Future<(String, Directory, Directory, Map<String, String>)> setUpCatalog(Directory temp) async {
    final home = p.join(temp.path, 'home');
    final src = Directory(p.join(temp.path, 'Antigo'));
    final dest = Directory(p.join(temp.path, 'Backup'));
    void write(Directory root, String rel, List<int> data) {
      final f = File(p.join(root.path, rel))..parent.createSync(recursive: true);
      f.writeAsBytesSync(data);
    }

    // Arquivos > 1 MiB: a falha "no meio da escrita" deixa um .part parcial de verdade.
    write(src, 'fotos/IMG_0001.jpg', bytes(1, 1500 * 1024));
    write(src, 'fotos/IMG_0002.jpg', bytes(2, 2100 * 1024));
    write(src, 'fotos/sub/VID_0003.mp4', bytes(3, 2600 * 1024));
    write(src, 'outras/IMG_0004.jpg', bytes(4, 1200 * 1024));
    // Destino: um arquivo diferente com o mesmo nome (não pode ser sobrescrito),
    // um que já é backup (não copia de novo) e um desconhecido na pasta temporária.
    write(dest, 'fotos/IMG_0002.jpg', bytes(99, 4096));
    write(dest, 'antigos/ja_tenho.jpg', bytes(4, 1200 * 1024));
    write(dest, '.fotoatlas-tmp/desconhecido.part', [1, 2, 3]);
    for (final args in [
      ['sources', 'add', src.path, '--name', 'Antigo'],
      ['sources', 'add', dest.path, '--name', 'Backup'],
      ['scan', 'start', 'Antigo'],
      ['scan', 'start', 'Backup'],
      ['hash', 'run'],
    ]) {
      final r = await run(home, args);
      expect(r.exitCode, 0, reason: '$args\n${r.stdout}${r.stderr}');
    }
    return (home, src, dest, tree(src));
  }

  final copyArgs = ['copy', 'start', 'Antigo', 'Backup', '--template', '{original}', '--yes'];

  Future<void> recoverThreeTimesAndFinish(
    String home,
    Directory src,
    Directory dest,
    Map<String, String> srcBefore,
  ) async {
    final snapshots = <String>[];
    for (var i = 0; i < 3; i++) {
      final r = await run(home, ['recover']);
      expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
      // A recuperação de verdade roda ao abrir; o comando roda de novo e não acha nada.
      expect(r.stdout as String, contains('RECOVER examinados=0'), reason: 'rodada ${i + 1}: ${r.stdout}');
      snapshots.add(snapshot(home, dest));
    }
    expect(snapshots[1], snapshots[0], reason: 'a 2ª recuperação não pode mudar nada');
    expect(snapshots[2], snapshots[0], reason: 'a 3ª recuperação não pode mudar nada');
    // Nada perdido nem sobrescrito até aqui.
    expect(tree(src), srcBefore, reason: 'a origem não muda');
    expect(sha(File(p.join(dest.path, 'fotos', 'IMG_0002.jpg')).readAsBytesSync()), sha(bytes(99, 4096)));
    expect(File(p.join(dest.path, '.fotoatlas-tmp', 'desconhecido.part')).readAsBytesSync(), [1, 2, 3]);

    final status = await run(home, ['copy', 'status']);
    final op = RegExp(r'OPERATION (\S+)').firstMatch(status.stdout as String)!.group(1)!;
    final resume = await run(home, ['copy', 'resume', op]);
    expect(resume.stdout as String, contains('COPY $op completed'), reason: '${resume.stdout}${resume.stderr}');

    final after = tree(dest);
    expect(after['fotos/IMG_0001.jpg'], sha(bytes(1, 1500 * 1024)));
    expect(after['fotos/IMG_0002_1.jpg'], sha(bytes(2, 2100 * 1024)), reason: 'conflito ganhou sufixo');
    expect(after['fotos/IMG_0002.jpg'], sha(bytes(99, 4096)), reason: 'o arquivo que já existia ficou intacto');
    expect(after['fotos/sub/VID_0003.mp4'], sha(bytes(3, 2600 * 1024)));
    expect(after.containsKey('outras/IMG_0004.jpg'), isFalse, reason: 'já estava no backup');
    expect(after['.fotoatlas-tmp/desconhecido.part'], sha([1, 2, 3]), reason: 'desconhecido nunca é apagado');
    expect(
      after.keys.where((k) => k.startsWith('.fotoatlas-tmp/') && k != '.fotoatlas-tmp/desconhecido.part'),
      isEmpty,
    );
    expect(after.length, 6);
    expect(tree(src), srcBefore);
    // Cada arquivo publicado aparece uma vez só no catálogo do destino, conferido.
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final rows = db.select(
        "SELECT rel_path FROM file_instances WHERE hash_status = 'done' AND source_id = (SELECT dest_source_id FROM operations) "
        "AND rel_path IN ('fotos/IMG_0001.jpg', 'fotos/IMG_0002_1.jpg', 'fotos/sub/VID_0003.mp4')",
      );
      expect(rows, hasLength(3));
      expect(db.select("SELECT COUNT(*) AS n FROM operation_items WHERE state = 'published'").first['n'], 3);
    } finally {
      db.close();
    }
  }

  const crashpoints = [
    'copy.after_copying_commit:2',
    'copy.mid_write:1',
    'copy.mid_write:3',
    'copy.after_flush:2',
    'copy.after_copied_commit:1',
    'copy.after_verifying_commit:2',
    'copy.after_verified_commit:1',
    'copy.after_publishing_commit:2',
    'copy.after_move:1',
    'copy.after_move:2',
    'copy.after_published_commit:3',
  ];

  /// Prova de que o processo morreu mesmo no estado pretendido: o diário e o
  /// disco, lidos antes de qualquer recuperação.
  void expectCrashState(String home, Directory dest, String point) {
    final db = sqlite3.open(p.join(home, 'catalog.db'), mode: OpenMode.readOnly);
    try {
      final open = db.select(
        "SELECT state, tmp_rel_path, dst_rel_path_final, expected_size FROM operation_items "
        "WHERE state NOT IN ('pending', 'published', 'skipped_identical') ORDER BY seq",
      );
      final published = db.select("SELECT COUNT(*) AS n FROM operation_items WHERE state = 'published'").first['n'];
      final name = point.split(':').first;
      if (name == 'copy.after_published_commit') {
        expect(open, isEmpty);
        expect(published, int.parse(point.split(':').last));
        return;
      }
      expect(open, hasLength(1), reason: 'um item no meio do protocolo');
      final row = open.single;
      final expectedState = switch (name) {
        'copy.after_copying_commit' || 'copy.mid_write' || 'copy.after_flush' => 'copying',
        'copy.after_copied_commit' => 'copied',
        'copy.after_verifying_commit' => 'verifying',
        'copy.after_verified_commit' => 'verified',
        _ => 'publishing',
      };
      expect(row['state'], expectedState);
      final part = File(p.join(dest.path, (row['tmp_rel_path'] as String).replaceAll('/', r'\')));
      final size = row['expected_size'] as int;
      switch (name) {
        case 'copy.after_copying_commit':
          expect(part.existsSync(), isFalse);
        case 'copy.mid_write':
          expect(part.lengthSync(), allOf(greaterThan(0), lessThan(size)), reason: '.part parcial');
        case 'copy.after_move':
          expect(part.existsSync(), isFalse, reason: 'já movido');
          expect(File(p.join(dest.path, row['dst_rel_path_final'] as String)).lengthSync(), size);
        default:
          expect(part.lengthSync(), size, reason: '.part completo');
          if (name == 'copy.after_publishing_commit') {
            expect(File(p.join(dest.path, row['dst_rel_path_final'] as String)).existsSync(), isFalse);
          }
      }
    } finally {
      db.close();
    }
  }

  for (final point in crashpoints) {
    test('morto em $point: recuperação 3× sem efeito colateral, cópia completa', () async {
      final temp = await createTestTemp();
      final (home, src, dest, srcBefore) = await setUpCatalog(temp);
      await runUntilCrash(home, copyArgs, point);
      expectCrashState(home, dest, point);
      await recoverThreeTimesAndFinish(home, src, dest, srcBefore);
    }, timeout: const Timeout(Duration(minutes: 3)));
  }

  test('morto no meio da própria recuperação: a próxima termina o serviço', () async {
    final temp = await createTestTemp();
    final (home, src, dest, srcBefore) = await setUpCatalog(temp);
    await runUntilCrash(home, copyArgs, 'copy.after_move:2');
    await runUntilCrash(home, ['recover'], 'recover.after_operation:1');
    await recoverThreeTimesAndFinish(home, src, dest, srcBefore);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
