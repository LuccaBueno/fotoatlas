import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sql;
import 'package:test/test.dart';

import '../support/test_core.dart';

void main() {
  test('backup com VACUUM INTO: cópia conferida, legível e com os dados', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', [1, 2, 3]);
    await env.scan(await env.addFolder('Fotos'));
    final backups = env.core.backups;

    final info = await backups.backupNow();
    expect(p.basename(info.path), matches(RegExp(r'^catalog-\d{8}-\d{6}\.db$')));
    expect(File('${info.path}.tmp').existsSync(), isFalse, reason: 'o temporário vira o backup final');
    final raw = sql.sqlite3.open(info.path, mode: sql.OpenMode.readOnly);
    addTearDown(raw.close);
    expect(raw.select('PRAGMA quick_check').single.values.single, 'ok');
    expect(raw.select('SELECT COUNT(*) AS n FROM file_instances').single['n'], 1);
    expect(backups.latest!.path, info.path);
  });

  test('rotação mantém os 10 mais novos e nunca apaga os de migração', () async {
    final env = await TestEnv.open();
    final backups = env.core.backups;
    Directory(backups.backupsDir).createSync(recursive: true);
    final migration = File(p.join(backups.backupsDir, 'pre-migracao-v1-20261026000000.db'))..writeAsStringSync('x');
    final base = DateTime.utc(2026, 1, 1, 12);
    for (var i = 0; i < 12; i++) {
      await backups.backupNow(now: base.add(Duration(days: i)));
    }
    final kept = backups.list();
    expect(kept, hasLength(10));
    expect(kept.first.createdAt, base.add(const Duration(days: 11)));
    expect(kept.last.createdAt, base.add(const Duration(days: 2)));
    expect(migration.existsSync(), isTrue);
  });

  test('nunca sobrescreve: dois backups no mesmo segundo ganham nomes diferentes', () async {
    final env = await TestEnv.open();
    final t = DateTime.utc(2026, 10, 27, 10);
    final a = await env.core.backups.backupNow(now: t);
    final b = await env.core.backups.backupNow(now: t);
    expect(a.path, isNot(b.path));
    expect(File(a.path).existsSync() && File(b.path).existsSync(), isTrue);
  });

  test('automático: só faz se o último tiver mais de 24 h', () async {
    final env = await TestEnv.open();
    final backups = env.core.backups;
    final t = DateTime.utc(2026, 10, 27, 10);
    expect(await backups.maybeBackup(now: t), isNotNull);
    expect(await backups.maybeBackup(now: t.add(const Duration(hours: 23))), isNull);
    expect(await backups.maybeBackup(now: t.add(const Duration(hours: 25))), isNotNull);
    expect(backups.list(), hasLength(2));
  });

  test('ao abrir com backupOnOpen, o core faz o primeiro backup', () async {
    final temp = await Directory.systemTemp.createTemp('fotoatlas_bkp_');
    addTearDown(() => temp.delete(recursive: true));
    final core = await FotoAtlasCore.open(
      paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
      volumes: _NoVolumes(),
      useHelper: false,
      backupOnOpen: true,
    );
    await core.close(); // espera o backup em segundo plano
    expect(Directory(p.join(temp.path, 'home', 'backups')).listSync().whereType<File>(), hasLength(1));
  });
}

class _NoVolumes implements VolumeProvider {
  @override
  Future<List<VolumeInfo>> list() async => const [];
}
