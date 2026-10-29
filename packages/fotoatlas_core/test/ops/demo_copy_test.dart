@Tags(['integration'])
library;

import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';
import '../support/tools.dart';

/// O cenário do roteiro de teste da Fase 5, ponta a ponta (helper real com o
/// celular simulado, ExifTool real): Pixel → "HD › Backup do celular" por ano
/// e mês. A foto de 02/05/2024 cai num nome que já existe no HD e ganha `_1`.
void main() {
  final helper = HelperClient.locate();
  final tools = ExternalTools.locate();

  test(
    'demo: copiar o que falta do Pixel para o HD mostra e resolve o conflito de nome',
    () async {
      final temp = await createTestTemp();
      final demo = generatePhoneDemo(p.join(temp.path, 'demo'));
      final conflict = File(p.join(demo.hdDir, 'Backup do celular', '2024', '2024-05', 'IMG_20240502_120000.jpg'));
      final before = conflict.readAsBytesSync();
      final core = await FotoAtlasCore.open(
        paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
        helperPath: helper,
        fakeDevicesDir: demo.devicesDir,
        tools: tools,
      );
      addTearDown(core.close);
      await core.sources.refreshConnectivity();
      final pixel = (await core.sources.listDevices()).firstWhere((d) => d.$1.friendlyName == 'Pixel de Teste').$1;
      final cel = (await core.sources.addPhone(pixel.deviceId)).sourceId;
      final hd = (await core.sources.addPath(demo.hdDir, name: 'HD')).sourceId;
      for (final id in [cel, hd]) {
        await core.scans.wait(await core.scans.start(id));
      }
      await core.hashes.start();
      await core.hashes.waitIdle();
      await core.metadata.start();
      await core.metadata.waitIdle();

      final a = Scope([ScopeEntry(cel, '')]);
      final ids = await core.compare.missingContentIds(a, Scope([ScopeEntry(hd, '')]));
      expect(ids, hasLength(3));
      final preview = await core.copies.preview(
        CopyRequest(contentIds: ids, destSourceId: hd, destFolder: 'Backup do celular', preferSourceIds: [cel]),
      );
      expect(preview.canStart, isTrue);
      expect(preview.renamedForConflict, 1);
      expect(
        preview.items.map((i) => i.dstRelPath),
        contains('Backup do celular/2024/2024-05/IMG_20240502_120000_1.jpg'),
      );
      final op = await core.copies.start(preview);
      await core.copies.waitIdle();
      expect((await core.copies.view(op))!.status, OpStatus.completed);
      expect(conflict.readAsBytesSync(), before, reason: 'o arquivo que já estava no HD fica intacto');
      expect((await core.compare.compare(a, Scope([ScopeEntry(hd, '')]))).verdict, CompareVerdict.complete);
    },
    skip: helper == null ? 'helper não compilado' : skipWithoutTool(tools.exiftool, 'ExifTool'),
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
