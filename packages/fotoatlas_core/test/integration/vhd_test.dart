@Tags(['integration'])
library;

import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';

/// Unidade real (VHD em temp) trocando de letra e sendo desconectada.
///
/// Exige administrador (diskpart). Só roda com FOTOATLAS_VHD_TESTS=1 — a CI
/// liga isso; na máquina do desenvolvedor fica desligado por padrão (ADR 0007).
final bool _enabled = Platform.environment['FOTOATLAS_VHD_TESTS'] == '1';

Future<void> diskpart(Directory temp, String script) async {
  final file = File(p.join(temp.path, 'diskpart_${DateTime.now().microsecondsSinceEpoch}.txt'))
    ..writeAsStringSync(script);
  final r = await Process.run('diskpart', ['/s', file.path]);
  expect(r.exitCode, 0, reason: 'diskpart falhou:\n$script\n${r.stdout}\n${r.stderr}');
}

Future<ProcessResult> powershell(String command) =>
    Process.run('powershell', ['-NoProfile', '-NonInteractive', '-Command', command]);

/// Estado real do VHD segundo a API de Storage do Windows.
Future<bool> vhdAttached(String vhd) async {
  final r = await powershell("\$ErrorActionPreference = 'Stop'; (Get-DiskImage -ImagePath '$vhd').Attached");
  expect(r.exitCode, 0, reason: 'Get-DiskImage falhou: ${r.stdout}\n${r.stderr}');
  return '${r.stdout}'.trim() == 'True';
}

/// Desanexa pela mesma API (Storage do Windows) que o [vhdAttached] consulta.
///
/// Antes usávamos `detach vdisk` do diskpart, que na CI às vezes respondia
/// "already detached". Conferido pelo `Get-DiskImage` (run 40546116893), o
/// disco continuava anexado depois desse passo nos dois testes: a resposta do
/// diskpart não refletia o estado real.
Future<void> dismount(String vhd) async {
  final r = await powershell("\$ErrorActionPreference = 'Stop'; Dismount-DiskImage -ImagePath '$vhd' | Out-Null");
  expect(r.exitCode, 0, reason: 'Dismount-DiskImage falhou: ${r.stdout}\n${r.stderr}');
}

List<String> freeLetters() => [
  for (final l in 'QRSTUVWXYZ'.split(''))
    if (!Directory('$l:\\').existsSync()) l,
];

void main() {
  for (final fs in ['ntfs', 'fat32']) {
    test(
      'VHD $fs: troca de letra reconhecida e desconexão mantém os dados',
      () async {
        final temp = await createTestTemp();
        final vhd = p.join(temp.path, 'teste_$fs.vhdx');
        final letters = freeLetters();
        expect(letters.length, greaterThanOrEqualTo(2), reason: 'precisa de 2 letras livres');
        final (first, second) = (letters[0], letters[1]);

        await diskpart(temp, '''
create vdisk file="$vhd" maximum=64 type=expandable
select vdisk file="$vhd"
attach vdisk
create partition primary
format fs=$fs quick label=FATESTE
assign letter=$first
''');
        // Limpeza se o teste parar antes do desanexo (aqui o erro é ignorado:
        // o disco pode já ter saído).
        addTearDown(() => powershell("Dismount-DiskImage -ImagePath '$vhd' -ErrorAction SilentlyContinue"));
        expect(await vhdAttached(vhd), isTrue);

        final fotos = Directory('$first:\\Fotos')..createSync();
        for (var i = 0; i < 20; i++) {
          File(p.join(fotos.path, 'IMG_$i.jpg')).writeAsBytesSync(List.filled(64, i));
        }

        final core = await FotoAtlasCore.open(
          paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
          scanInIsolate: true,
          // Helper real, mas sem WPD: nenhum celular conectado é lido (CLAUDE.md).
          fakeDevicesDir: (Directory(p.join(temp.path, 'sem_celulares'))..createSync()).path,
        );
        addTearDown(core.close);

        final id = (await core.sources.addPath('$first:\\')).sourceId;
        expect((await core.scans.wait(await core.scans.start(id))).filesSeen, 20);

        await diskpart(temp, 'select volume $first\nremove letter=$first\nassign letter=$second\n');
        await core.sources.refreshConnectivity();
        var view = (await core.sources.list()).single;
        expect(view.state, SourceState.connected, reason: 'mesma unidade com outra letra');
        expect(view.displayPath, '$second:\\');
        final rescan = await core.scans.wait(await core.scans.start(id));
        expect(rescan.status, 'completed');
        expect(view.missingCount, 0);

        await diskpart(temp, 'select volume $second\nremove letter=$second\n');
        // Sem letra o volume continua acessível pelo GUID; desanexa de vez.
        await dismount(vhd);
        expect(await vhdAttached(vhd), isFalse, reason: 'o VHD deveria estar desanexado');
        await core.sources.refreshConnectivity();
        view = (await core.sources.list()).single;
        expect(view.state, SourceState.disconnected);
        expect(view.fileCount, 20, reason: 'desconectada não é vazia');
        expect(view.lastScan?.status, 'completed');
      },
      skip: _enabled ? false : 'defina FOTOATLAS_VHD_TESTS=1 (exige administrador)',
      timeout: const Timeout(Duration(minutes: 3)),
    );
  }
}
