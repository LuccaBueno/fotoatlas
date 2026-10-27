import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';
import 'temp.dart';

/// Ambiente de teste: catálogo em temp + um "volume" simulado (pasta real).
class TestEnv {
  TestEnv._(this.temp, this.core, this.volumes, this.volumeDir);

  final Directory temp;
  final FotoAtlasCore core;
  final FakeVolumeProvider volumes;

  /// Pasta que faz o papel da raiz do volume simulado.
  final Directory volumeDir;

  static Future<TestEnv> open({
    bool isolate = false,
    VolumeInfo Function(String root)? volume,
    DeviceBackend? devices,
  }) async {
    final temp = await createTestTemp();
    final volumeDir = Directory(p.join(temp.path, 'volume_e'))..createSync();
    assertInTemp(volumeDir.path);
    final provider = FakeVolumeProvider()..volumes = [volume?.call(volumeDir.path) ?? fakeVolume(volumeDir.path)];
    final core = await FotoAtlasCore.open(
      paths: CorePaths(dataDir: p.join(temp.path, 'home'), localDir: p.join(temp.path, 'local')),
      volumes: provider,
      pathResolver: FakePathResolver(provider),
      useHelper: false,
      scanInIsolate: isolate,
      hashInIsolate: isolate,
      devices: devices,
    );
    final env = TestEnv._(temp, core, provider, volumeDir);
    addTearDown(env.close);
    return env;
  }

  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await core.close();
  }

  CatalogDatabase get db => core.catalog.db;

  /// Cria mais um volume simulado (outro "HD"), com disco físico próprio.
  Directory addVolume(String name, {String? diskSerial, String diskConfidence = 'reliable', String mount = r'F:\'}) {
    final dir = Directory(p.join(temp.path, 'volume_$name'))..createSync();
    assertInTemp(dir.path);
    volumes.volumes = [
      ...volumes.volumes,
      fakeVolume(
        dir.path,
        mount: mount,
        label: name,
        serial: 0x1000 + volumes.volumes.length,
        diskSerial: diskSerial ?? 'DISCO-$name',
        diskConfidence: diskConfidence,
      ),
    ];
    return dir;
  }

  /// Cadastra [relDir] do volume simulado como fonte (cria a pasta se preciso).
  /// Sem [volume], usa o volume principal.
  Future<String> addFolder(String relDir, {String? name, Directory? volume}) async {
    final dir = Directory(p.join((volume ?? volumeDir).path, relDir))..createSync(recursive: true);
    return (await core.sources.addPath(dir.path, name: name)).sourceId;
  }

  /// Escaneia até o fim e devolve o progresso final.
  Future<ScanProgress> scan(String sourceId) async {
    final id = await core.scans.start(sourceId);
    return core.scans.wait(id);
  }

  /// Confere o conteúdo de tudo o que estiver pendente e espera terminar.
  Future<void> hashAll() async {
    await core.hashes.start();
    await core.hashes.waitIdle();
  }

  /// Escreve um arquivo (cria as pastas) e devolve o caminho.
  File write(String relPath, List<int> bytes, {Directory? volume}) {
    final f = File(p.join((volume ?? volumeDir).path, relPath));
    f.parent.createSync(recursive: true);
    assertInTemp(f.path);
    return f..writeAsBytesSync(bytes);
  }

  Future<int> count(String sql, [List<Object?> args = const []]) async {
    final row = await db.customSelect(sql, variables: [for (final a in args) _variable(a)]).getSingle();
    return row.data.values.first as int;
  }
}

Variable<Object> _variable(Object? value) => switch (value) {
  final int v => Variable.withInt(v),
  final String v => Variable.withString(v),
  _ => throw ArgumentError(value),
};
