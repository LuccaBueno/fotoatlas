import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

/// Guarda onde cada arquivo foi parar na Lixeira, para o teste tirar de lá no fim.
class _Recording implements RecycleBin {
  _Recording(this.inner);
  final RecycleBin inner;
  final recycled = <String>[];

  @override
  Future<RecycleOutcome> recycle(String path, {required int size, required int? mtime}) async {
    final o = await inner.recycle(path, size: size, mtime: mtime);
    if (o.recycledPath != null) recycled.add(o.recycledPath!);
    return o;
  }
}

/// "Limpar repetidos" com o helper e a **Lixeira de verdade** do Windows,
/// só com arquivos sintéticos no temporário do teste. O que o teste manda
/// para a Lixeira é tirado de lá no fim (`$R…` e `$I…`).
void main() {
  final exe = HelperClient.locate();

  test('a cópia repetida vai para a Lixeira do Windows, inteira, e a que fica continua', () async {
    final client = HelperClient(executable: exe!);
    await client.start();
    addTearDown(client.close);
    final bin = _Recording(HelperRecycleBin(client));
    addTearDown(() {
      for (final r in bin.recycled) {
        expect(r, contains(r'\$Recycle.Bin\'));
        final name = p.basename(r);
        File(r).deleteSync();
        final info = File(p.join(p.dirname(r), '\$I${name.substring(2)}'));
        if (info.existsSync()) info.deleteSync();
      }
    });
    final env = await TestEnv.open(tools: ExternalTools.none, recycleBin: bin);
    final data = List.generate(5000, (i) => (i * 31) & 0xff);
    env
      ..write('HD/2024/foto.jpg', data)
      ..write('HD/Downloads/foto (1).jpg', data);
    final hd = await env.addFolder('HD');
    await env.scan(hd);
    await env.hashAll();
    final g = (await env.core.dedupe.groups(hd)).single;
    final id = await env.core.dedupe.start(
      await env.core.dedupe.preview(hd, [DedupeChoice(g.contentId, g.suggestedKeepId)]),
    );
    await env.core.dedupe.waitIdle();
    final o = (await env.core.copies.view(id))!;
    expect((o.status, o.published), (OpStatus.completed, 1));
    expect(File(p.join(env.volumeDir.path, 'HD', '2024', 'foto.jpg')).readAsBytesSync(), data);
    expect(File(p.join(env.volumeDir.path, 'HD', 'Downloads', 'foto (1).jpg')).existsSync(), isFalse);
    expect(bin.recycled, hasLength(1));
    expect(sha256.convert(File(bin.recycled.single).readAsBytesSync()), sha256.convert(data));
  }, skip: exe == null ? 'helper não compilado (dotnet build em native/fotoatlas_helper)' : false);
}
