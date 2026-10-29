import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/fakes.dart';
import '../support/test_core.dart';

void main() {
  test('cadastra uma pasta: conectada, com caminho relativo e letra atual', () async {
    final env = await TestEnv.open();
    final id = await env.addFolder('Fotos/2019', name: 'Fotos 2019');
    final view = (await env.core.sources.list()).single;
    expect(view.id, id);
    expect(view.name, 'Fotos 2019');
    expect(view.kind, 'folder');
    expect(view.rootRelPath, 'Fotos/2019');
    expect(view.state, SourceState.connected);
    expect(view.displayPath, r'E:\Fotos\2019');
  });

  test('cadastra a unidade inteira com tipo deduzido (HD externo USB)', () async {
    final env = await TestEnv.open();
    await env.core.sources.addPath(env.volumeDir.path);
    final view = (await env.core.sources.list()).single;
    expect(view.kind, 'external_hd');
    expect(view.name, 'Backup1');
    expect(view.rootRelPath, '');
  });

  test('recusa cadastro duplicado e avisa sobreposição', () async {
    final env = await TestEnv.open();
    await env.addFolder('Fotos', name: 'Fotos');
    await expectLater(env.addFolder('fotos'), throwsA(isA<SourceException>()));
    final dir = Directory(p.join(env.volumeDir.path, 'Fotos', 'Viagem'))..createSync();
    final result = await env.core.sources.addPath(dir.path);
    expect(result.warnings.single, contains('fica dentro de "Fotos"'));
  });

  test('recusa pasta inexistente', () async {
    final env = await TestEnv.open();
    await expectLater(
      env.core.sources.addPath(p.join(env.volumeDir.path, 'nao_existe')),
      throwsA(isA<SourceException>()),
    );
  });

  test('troca de letra: a mesma fonte é reconhecida e continua escaneável', () async {
    final env = await TestEnv.open();
    final id = await env.addFolder('Fotos');
    File(p.join(env.volumeDir.path, 'Fotos', 'IMG_1.jpg')).writeAsBytesSync([1, 2, 3]);

    env.volumes.volumes = [fakeVolume(env.volumeDir.path, mount: r'G:\')];
    await env.core.sources.refreshConnectivity();

    final view = (await env.core.sources.list()).single;
    expect(view.state, SourceState.connected);
    expect(view.displayPath, r'G:\Fotos');
    expect((await env.scan(id)).filesSeen, 1);
    final row = await env.core.sources.byId(id);
    expect(row!.lastMountPath, r'G:\');
  });

  test('fonte desconectada continua visível com os dados do último scan', () async {
    final env = await TestEnv.open();
    final id = await env.addFolder('Fotos');
    for (var i = 0; i < 3; i++) {
      File(p.join(env.volumeDir.path, 'Fotos', 'IMG_$i.jpg')).writeAsBytesSync([i]);
    }
    await env.scan(id);

    env.volumes.volumes = [];
    await env.core.sources.refreshConnectivity();

    final view = (await env.core.sources.list()).single;
    expect(view.state, SourceState.disconnected);
    expect(view.fileCount, 3, reason: 'desconectada não é vazia (regra 9)');
    expect(view.mediaCount, 3);
    expect(view.missingCount, 0);
    expect(view.lastScan?.status, 'completed');
    expect(view.displayPath, r'E:\Fotos', reason: 'mostra o último caminho visto');
    await expectLater(env.core.scans.start(id), throwsA(isA<SourceException>()));
  });

  test('caso ambíguo pede confirmação; depois de confirmado, conecta', () async {
    final env = await TestEnv.open();
    final id = await env.addFolder('Fotos');
    final clone = Directory(p.join(env.temp.path, 'clone'))..createSync();
    // Mesmo serial/rótulo/disco, GUIDs diferentes do original: dois candidatos fortes.
    env.volumes.volumes = [fakeVolume(p.join(env.temp.path, 'outro')), fakeVolume(clone.path, mount: r'H:\')];
    await env.core.sources.refreshConnectivity();
    final view = (await env.core.sources.list()).single;
    expect(view.state, SourceState.ambiguous);
    expect(view.candidates, hasLength(2));

    await env.core.sources.confirmVolume(id, env.volumes.volumes[1].guidPath);
    final after = (await env.core.sources.list()).single;
    expect(after.state, SourceState.connected);
    expect(after.displayPath, r'H:\Fotos');
  });

  test('esquecer oculta a fonte mas não apaga o catálogo de arquivos', () async {
    final env = await TestEnv.open();
    final id = await env.addFolder('Fotos');
    File(p.join(env.volumeDir.path, 'Fotos', 'IMG_1.jpg')).writeAsBytesSync([1]);
    await env.scan(id);
    await env.core.sources.forget(id);
    expect(await env.core.sources.list(), isEmpty);
    expect(await env.count('SELECT COUNT(*) FROM file_instances WHERE source_id = ?', [id]), 1);
    expect(File(p.join(env.volumeDir.path, 'Fotos', 'IMG_1.jpg')).existsSync(), isTrue);
  });

  test('watch emite atualização quando a conectividade muda', () async {
    final env = await TestEnv.open();
    await env.addFolder('Fotos');
    final states = <SourceState>[];
    final sub = env.core.sources.watch().listen((list) => states.add(list.single.state));
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    env.volumes.volumes = [];
    await env.core.sources.refreshConnectivity();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(states.first, SourceState.connected);
    expect(states.last, SourceState.disconnected);
  });

  test('unidades para "Adicionar dispositivo": cadastradas marcadas, pasta não conta como unidade', () async {
    final env = await TestEnv.open();
    env.addVolume('Pendrive', mount: r'F:\');
    await env.addFolder('Fotos');
    var drives = await env.core.sources.listDrives();
    expect(drives.map((d) => d.$1.displayMount), [r'E:\', r'F:\']);
    expect(drives.every((d) => d.$2 == null), isTrue, reason: 'só uma pasta de E: foi cadastrada');
    final id = (await env.core.sources.addPath(env.volumeDir.path)).sourceId;
    drives = await env.core.sources.listDrives();
    expect(drives.first.$2, id);
    expect(drives.last.$2, isNull);
    expect(SourcesService.kindForVolume(drives.first.$1), 'external_hd');
  });
}
