@Tags(['integration'])
library;

import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';
import 'vhd_test.dart' show diskpart, freeLetters, powershell, vhdAttached;

/// Cópia para discos reais (VHD em temp): FAT32 com arquivo acima de 4 GB e
/// disco que enche no meio. Exige administrador; só com FOTOATLAS_VHD_TESTS=1
/// (a CI liga; ADR 0007).
final bool _enabled = Platform.environment['FOTOATLAS_VHD_TESTS'] == '1';

List<int> randomBytes(int seed, int length) {
  final r = Random(seed);
  return List.generate(length, (_) => r.nextInt(256));
}

String sha(List<int> b) => sha256.convert(b).toString();

Future<String> attachVhd(
  Directory temp,
  String name, {
  required int sizeMb,
  required String fs,
  required String label,
}) async {
  final vhd = p.join(temp.path, '$name.vhdx');
  final letter = freeLetters().first;
  await diskpart(temp, '''
create vdisk file="$vhd" maximum=$sizeMb type=expandable
select vdisk file="$vhd"
attach vdisk
create partition primary
format fs=$fs quick label=$label
assign letter=$letter
''');
  addTearDown(() => powershell("Dismount-DiskImage -ImagePath '$vhd' -ErrorAction SilentlyContinue"));
  expect(await vhdAttached(vhd), isTrue);
  return '$letter:\\';
}

Future<FotoAtlasCore> openCore(Directory temp, {FreeSpaceProbe? freeSpace}) async {
  final core = await FotoAtlasCore.open(
    paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
    // Helper real, mas sem WPD: nenhum celular conectado é lido (CLAUDE.md).
    fakeDevicesDir: (Directory(p.join(temp.path, 'sem_celulares'))..createSync()).path,
    freeSpace: freeSpace,
  );
  addTearDown(core.close);
  return core;
}

Future<void> scanAndHash(FotoAtlasCore core, List<String> ids) async {
  for (final id in ids) {
    expect((await core.scans.wait(await core.scans.start(id))).status, 'completed');
  }
  await core.hashes.start();
  await core.hashes.waitIdle();
}

void main() {
  test(
    'FAT32 real: > 4 GB fica de fora da prévia; se escapar, o disco recusa e nada é publicado',
    () async {
      final temp = await createTestTemp();
      final root = await attachVhd(temp, 'fat32_grande', sizeMb: 6144, fs: 'fat32', label: 'FATCOPIA');
      final src = Directory(p.join(temp.path, 'Origem'))..createSync();
      File(p.join(src.path, 'a.jpg')).writeAsBytesSync(randomBytes(1, 1 << 20));
      File(p.join(src.path, 'b.jpg')).writeAsBytesSync(randomBytes(2, 2 << 20));
      // 4 GiB + 1 MiB esparso (não ocupa o disco de quem roda o teste).
      final big = File(p.join(src.path, 'grande.mp4'))..createSync();
      final fsutil = await Process.run('fsutil', ['sparse', 'setflag', big.path]);
      expect(fsutil.exitCode, 0, reason: '${fsutil.stdout}${fsutil.stderr}');
      final raf = big.openSync(mode: FileMode.append);
      raf
        ..setPositionSync((4 << 30) + (1 << 20) - 1)
        ..writeByteSync(1)
        ..closeSync();
      Directory('${root}Backup').createSync();

      final core = await openCore(temp);
      final a = (await core.sources.addPath(src.path, name: 'Origem')).sourceId;
      final b = (await core.sources.addPath('${root}Backup', name: 'Pendrive')).sourceId;
      expect((await core.sources.byId(b))!.filesystem, 'FAT32');
      for (final id in [a, b]) {
        expect((await core.scans.wait(await core.scans.start(id))).status, 'completed');
      }
      // Não lê 4 GB para conferir: o teste registra o conteúdo do grande direto no catálogo.
      await core.catalog.db.customStatement(
        "UPDATE file_instances SET hash_status = 'not_applicable' WHERE name = 'grande.mp4'",
      );
      await core.hashes.start();
      await core.hashes.waitIdle();
      await core.catalog.db.customStatement(
        "INSERT INTO contents (sha256, size_bytes, media_type, created_at) VALUES (zeroblob(32), ${(4 << 30) + (1 << 20)}, 'video', 0)",
      );
      await core.catalog.db.customStatement(
        "UPDATE file_instances SET hash_status = 'done', content_id = (SELECT id FROM contents WHERE media_type = 'video') "
        "WHERE name = 'grande.mp4'",
      );

      final ids = await core.compare.missingContentIds(Scope([ScopeEntry(a, '')]), Scope([ScopeEntry(b, '')]));
      expect(ids, hasLength(3));
      final preview = await core.copies.preview(CopyRequest(contentIds: ids, destSourceId: b, template: ''));
      expect(preview.tooLargeForFat32.single.name, 'grande.mp4');
      expect(preview.items, hasLength(2));
      final op = await core.copies.start(preview);
      await core.copies.waitIdle();
      expect((await core.copies.view(op))!.status, OpStatus.completed);
      expect(sha(File('${root}Backup\\a.jpg').readAsBytesSync()), sha(randomBytes(1, 1 << 20)));

      // Identificação errada do sistema de arquivos: a checagem prévia deixa
      // passar, mas o próprio FAT32 recusa no meio da escrita.
      await core.catalog.db.customUpdate(
        "UPDATE sources SET filesystem = 'NTFS' WHERE id = ?",
        variables: [Variable.withString(b)],
      );
      final forced = await core.copies.preview(CopyRequest(contentIds: ids, destSourceId: b, template: ''));
      expect(forced.items.single.srcRelPath, 'grande.mp4');
      final op2 = await core.copies.start(forced);
      await core.copies.waitIdle();
      final view = (await core.copies.view(op2))!;
      expect(view.published, 0);
      expect(File('${root}Backup\\grande.mp4').existsSync(), isFalse);
      final tmp = Directory('${root}Backup\\.fotoatlas-tmp');
      expect(tmp.existsSync() ? tmp.listSync() : const [], isEmpty, reason: 'o parcial (nosso) foi descartado');
      expect(File('${root}Backup\\a.jpg').lengthSync(), 1 << 20, reason: 'o que já estava lá ficou intacto');
    },
    skip: _enabled ? false : 'defina FOTOATLAS_VHD_TESTS=1 (exige administrador)',
    timeout: const Timeout(Duration(minutes: 10)),
  );

  test(
    'disco cheio de verdade no meio da cópia: pausa, nada pela metade, e a prévia avisa',
    () async {
      final temp = await createTestTemp();
      final root = await attachVhd(temp, 'cheio', sizeMb: 64, fs: 'ntfs', label: 'CHEIO');
      final src = Directory(p.join(temp.path, 'Origem'))..createSync();
      for (var i = 0; i < 3; i++) {
        File(p.join(src.path, 'VID_$i.mp4')).writeAsBytesSync(randomBytes(10 + i, 25 << 20));
      }
      Directory('${root}Backup').createSync();
      // A checagem de espaço "mente" (como outro programa enchendo o disco no meio).
      var lie = true;
      final core = await openCore(temp, freeSpace: (_) => lie ? 1 << 40 : diskFree(root));
      final a = (await core.sources.addPath(src.path, name: 'Origem')).sourceId;
      final b = (await core.sources.addPath('${root}Backup', name: 'HD pequeno')).sourceId;
      await scanAndHash(core, [a, b]);
      final ids = await core.compare.missingContentIds(Scope([ScopeEntry(a, '')]), Scope([ScopeEntry(b, '')]));
      final op = await core.copies.start(
        await core.copies.preview(CopyRequest(contentIds: ids, destSourceId: b, template: '')),
      );
      await core.copies.waitIdle();
      final view = (await core.copies.view(op))!;
      expect(view.status, OpStatus.paused);
      expect(view.pauseReason, contains('espaço'));
      expect(view.published, inInclusiveRange(1, 2));
      final tmp = Directory('${root}Backup\\.fotoatlas-tmp');
      expect(tmp.listSync(), isEmpty, reason: 'nenhum .part pela metade');
      for (final f in Directory('${root}Backup').listSync().whereType<File>()) {
        final i = int.parse(p.basenameWithoutExtension(f.path).split('_').last);
        expect(sha(f.readAsBytesSync()), sha(randomBytes(10 + i, 25 << 20)), reason: 'publicado = conferido');
      }
      lie = false;
      final again = await core.copies.preview(CopyRequest(contentIds: ids, destSourceId: b, template: ''));
      expect(again.enoughSpace, isFalse);
    },
    skip: _enabled ? false : 'defina FOTOATLAS_VHD_TESTS=1 (exige administrador)',
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

int? diskFree(String root) {
  final r = Process.runSync('powershell', [
    '-NoProfile',
    '-Command',
    "(Get-PSDrive -Name '${root.substring(0, 1)}').Free",
  ]);
  return int.tryParse('${r.stdout}'.trim());
}
