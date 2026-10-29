@Tags(['slow'])
library;

import 'dart:typed_data';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

/// Cobertura e comparação com 100 mil arquivos no catálogo (3 fontes, ~1/3
/// repetidos entre elas). Só o catálogo é usado: as linhas são inseridas
/// direto, sem arquivos no disco. Mede o tempo e exige < 5 s por consulta (a
/// meta prática é bem menor; o limite largo evita teste instável em CI lenta).
void main() {
  test('100 mil arquivos: relatório de cobertura e comparação respondem rápido', () async {
    final env = await TestEnv.open();
    final hd2 = env.addVolume('HD2');
    final s1 = await env.addFolder('Celular');
    final s2 = await env.addFolder('Backup');
    final s3 = await env.addFolder('Antigo', volume: hd2);
    final db = env.db;
    const perSource = 33334;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction(() async {
      await db.batch((b) {
        for (var i = 0; i < 60000; i++) {
          final sha = Uint8List(32)..buffer.asByteData().setUint32(0, i);
          b.customStatement(
            'INSERT INTO contents (id, sha256, size_bytes, media_type, created_at) VALUES (?, ?, ?, ?, ?)',
            [i + 1, sha, 1000 + i, 'photo', now],
          );
        }
        var n = 0;
        for (final (source, offset) in [(s1, 0), (s2, 20000), (s3, 26666)]) {
          for (var i = 0; i < perSource; i++) {
            final content = offset + i + 1;
            final dir = 'd${i % 200}';
            b.customStatement(
              'INSERT INTO file_instances (source_id, rel_path, dir_rel_path, name, ext, size_bytes, mtime, '
              "content_id, hash_status, availability) VALUES (?, ?, ?, ?, 'jpg', ?, 1, ?, 'done', 'present')",
              [source, '$dir/IMG_$i.jpg', dir, 'IMG_$i.jpg', 1000 + content - 1, content],
            );
            n++;
          }
        }
        expect(n, 100002);
      });
    });

    final sw = Stopwatch()..start();
    final report = await env.core.coverage.report();
    final coverageMs = sw.elapsedMilliseconds;
    expect(report.overall.totalFiles, greaterThan(50000));

    sw.reset();
    final a = Scope([ScopeEntry(s1)]);
    final b = Scope([ScopeEntry(s2), ScopeEntry(s3)]);
    final r = await env.core.compare.compare(a, b);
    final compareMs = sw.elapsedMilliseconds;
    // Celular: conteúdos 1..33334; Backup: 20001..53334; Antigo: 26667..60000 → faltam 1..20000.
    expect(r.missing.contents, 20000);
    expect(r.inBoth.contents, 13334);

    sw.reset();
    final page = await env.core.compare.items(a, b, CompareList.missing, limit: 200);
    final pageMs = sw.elapsedMilliseconds;
    expect(page, hasLength(200));

    // ignore: avoid_print
    print('cobertura: $coverageMs ms · comparação: $compareMs ms · página da lista: $pageMs ms (100.002 arquivos)');
    expect(coverageMs, lessThan(5000));
    expect(compareMs, lessThan(5000));
    expect(pageMs, lessThan(5000));
  });
}
