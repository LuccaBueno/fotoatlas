import 'dart:io';

import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

void main() {
  for (final isolate in [false, true]) {
    group(isolate ? 'em isolate' : 'no mesmo isolate', () {
      test('escaneamento completo cataloga exatamente a árvore gerada', () async {
        final env = await TestEnv.open(isolate: isolate);
        final root = p.join(env.volumeDir.path, 'Fotos');
        final manifest = generateTree(root, const FixtureOptions(files: 1500, seed: 3));
        final id = await env.addFolder('Fotos');

        final result = await env.scan(id);
        expect(result.status, 'completed');
        expect(result.filesSeen, manifest.files);
        expect(result.bytesSeen, manifest.bytes);
        expect(result.errorCount, 0);
        expect(await env.count('SELECT COUNT(*) FROM file_instances WHERE source_id = ?', [id]), manifest.files);
        expect(await env.count("SELECT COUNT(*) FROM scans WHERE source_id = ? AND coverage = 'complete'", [id]), 1);
        // Caminho longo e nomes Unicode estão no catálogo, relativos à raiz da fonte.
        expect(await env.count('SELECT COUNT(*) FROM file_instances WHERE rel_path = ?', [manifest.longPathFile!]), 1);
        expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE rel_path LIKE '日本旅行/%'"), greaterThan(0));
      });
    });
  }

  test('scan incremental: só o arquivo alterado volta para "hash pendente"', () async {
    final env = await TestEnv.open();
    final dir = Directory(p.join(env.volumeDir.path, 'Fotos'))..createSync();
    final a = File(p.join(dir.path, 'a.jpg'))..writeAsBytesSync([1, 2, 3]);
    File(p.join(dir.path, 'b.jpg')).writeAsBytesSync([4, 5, 6]);
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    // Simula hashes já calculados (Fase 2).
    await env.db.customStatement("UPDATE file_instances SET hash_status = 'done'");

    a.writeAsBytesSync([1, 2, 3, 4]);
    final second = await env.scan(id);
    expect(second.status, 'completed');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE name = 'a.jpg' AND hash_status = 'pending'"), 1);
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE name = 'b.jpg' AND hash_status = 'done'"), 1);
    expect(await env.count("SELECT COUNT(*) FROM scans WHERE source_id = ? AND kind = 'incremental'", [id]), 1);
  });

  test('ausência só é confirmada em scan completo; arquivos e pastas apagados', () async {
    final env = await TestEnv.open();
    final dir = Directory(p.join(env.volumeDir.path, 'Fotos', 'sub'))..createSync(recursive: true);
    File(p.join(env.volumeDir.path, 'Fotos', 'fica.jpg')).writeAsBytesSync([1]);
    final some = File(p.join(env.volumeDir.path, 'Fotos', 'some.jpg'))..writeAsBytesSync([2]);
    File(p.join(dir.path, 'na_pasta.jpg')).writeAsBytesSync([3]);
    final id = await env.addFolder('Fotos');
    await env.scan(id);

    some.deleteSync();
    dir.deleteSync(recursive: true);
    await env.scan(id);

    expect(
      await env.count(
        "SELECT COUNT(*) FROM file_instances WHERE availability = 'missing' AND missing_confirmed_at IS NOT NULL",
      ),
      2,
    );
    expect(
      await env.count("SELECT COUNT(*) FROM file_instances WHERE name = 'fica.jpg' AND availability = 'present'"),
      1,
    );

    // Se o arquivo voltar, a instância volta a "presente".
    some.writeAsBytesSync([2]);
    await env.scan(id);
    expect(
      await env.count(
        "SELECT COUNT(*) FROM file_instances WHERE name = 'some.jpg' AND availability = 'present' AND missing_confirmed_at IS NULL",
      ),
      1,
    );
  });

  test('pasta sem permissão: erro registrado, cobertura parcial e nada marcado como ausente', () async {
    final env = await TestEnv.open();
    final locked = Directory(p.join(env.volumeDir.path, 'Fotos', 'trancada'))..createSync(recursive: true);
    File(p.join(locked.path, 'segredo.jpg')).writeAsBytesSync([1]);
    File(p.join(env.volumeDir.path, 'Fotos', 'livre.jpg')).writeAsBytesSync([2]);
    final id = await env.addFolder('Fotos');
    await env.scan(id);

    // Nega listagem para "Todos" (S-1-1-0) e restaura no fim.
    final deny = await Process.run('icacls', [locked.path, '/deny', '*S-1-1-0:(RD)']);
    expect(deny.exitCode, 0, reason: '${deny.stdout}${deny.stderr}');
    addTearDown(() => Process.run('icacls', [locked.path, '/remove:d', '*S-1-1-0']));

    final second = await env.scan(id);
    expect(second.status, 'completed');
    expect(second.errorCount, 1);
    expect(await env.count("SELECT COUNT(*) FROM scans WHERE source_id = ? AND coverage = 'partial'", [id]), 1);
    expect(
      await env.count("SELECT COUNT(*) FROM scan_errors WHERE kind = 'access_denied' AND rel_path = 'trancada'"),
      1,
    );
    expect(
      await env.count("SELECT COUNT(*) FROM file_instances WHERE name = 'segredo.jpg' AND availability = 'present'"),
      1,
      reason: 'falha de leitura não é exclusão (regra 10)',
    );
  });

  test('exclusões e junctions: nada de lixeira, temporários ou contagem dupla', () async {
    final env = await TestEnv.open();
    final base = p.join(env.volumeDir.path, 'Fotos');
    final target = Directory(p.join(base, 'real'))..createSync(recursive: true);
    File(p.join(target.path, 'foto.jpg')).writeAsBytesSync([1]);
    Directory(p.join(base, r'$RECYCLE.BIN')).createSync();
    File(p.join(base, r'$RECYCLE.BIN', 'lixo.jpg')).writeAsBytesSync([2]);
    Directory(p.join(base, '.fotoatlas-tmp')).createSync();
    File(p.join(base, '.fotoatlas-tmp', 'x.part')).writeAsBytesSync([3]);
    final r = await Process.run('cmd', ['/c', 'mklink', '/J', p.join(base, 'atalho'), target.path]);
    expect(r.exitCode, 0);
    final id = await env.addFolder('Fotos');

    final result = await env.scan(id);
    expect(result.filesSeen, 1);
    expect(
      await env.count("SELECT COUNT(*) FROM scan_errors WHERE kind = 'reparse_point_skipped' AND rel_path = 'atalho'"),
      1,
    );
    expect(result.errorCount, 0, reason: 'link não seguido não é erro');
  });

  test('pausar e retomar: contagem exata, sem duplicatas', () async {
    final env = await TestEnv.open();
    final manifest = generateTree(p.join(env.volumeDir.path, 'Fotos'), const FixtureOptions(files: 3000, seed: 9));
    final id = await env.addFolder('Fotos');

    final scanId = await env.core.scans.start(id);
    await env.core.scans.pause(scanId);
    final paused = await env.core.scans.wait(scanId);
    expect(paused.status, 'paused');

    expect(await env.core.scans.start(id), scanId, reason: 'retoma o mesmo scan');
    final done = await env.core.scans.wait(scanId);
    expect(done.status, 'completed');
    expect(done.filesSeen, manifest.files);
    expect(await env.count('SELECT COUNT(*) FROM file_instances'), manifest.files);
  });

  test('cancelar não confirma ausências', () async {
    final env = await TestEnv.open();
    final dir = Directory(p.join(env.volumeDir.path, 'Fotos'))..createSync();
    final f = File(p.join(dir.path, 'a.jpg'))..writeAsBytesSync([1]);
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    f.deleteSync();

    final scanId = await env.core.scans.start(id);
    await env.core.scans.cancel(scanId);
    expect((await env.core.scans.wait(scanId)).status, 'cancelled');
    expect(await env.count("SELECT COUNT(*) FROM file_instances WHERE availability = 'missing'"), 0);
  });

  test('scan que estava rodando quando o processo morreu é retomado', () async {
    final env = await TestEnv.open();
    File(p.join((Directory(p.join(env.volumeDir.path, 'Fotos'))..createSync()).path, 'a.jpg')).writeAsBytesSync([1]);
    final id = await env.addFolder('Fotos');
    await env.db.customStatement(
      "INSERT INTO scans (id, source_id, kind, status, started_at) VALUES (77, '$id', 'full', 'running', 0)",
    );
    await env.db.customStatement("INSERT INTO scan_dirs (scan_id, rel_path, status) VALUES (77, '', 'pending')");
    await env.core.scans.init();
    expect(await env.count("SELECT COUNT(*) FROM scans WHERE id = 77 AND status = 'interrupted'"), 1);
    expect(await env.core.scans.start(id), 77);
    expect((await env.core.scans.wait(77)).status, 'completed');
  });
}
