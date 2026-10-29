import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'fakes.dart';
import 'temp.dart';

/// Ambiente de teste: catálogo em temp + um "volume" simulado (pasta real).
class TestEnv {
  TestEnv._(this.temp, this.core, this.volumes, this.volumeDir, this._isolate);

  final Directory temp;
  FotoAtlasCore core;
  final bool _isolate;
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
    final env = TestEnv._(temp, core, provider, volumeDir, isolate);
    addTearDown(env.close);
    return env;
  }

  /// Fecha e abre de novo o mesmo catálogo (como fechar e abrir o app).
  Future<void> reopen({DeviceBackend? devices}) async {
    await core.close();
    core = await FotoAtlasCore.open(
      paths: core.paths,
      volumes: volumes,
      pathResolver: FakePathResolver(volumes),
      useHelper: false,
      scanInIsolate: _isolate,
      hashInIsolate: _isolate,
      devices: devices,
    );
  }

  bool _closed = false;
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    var steps = const <ShutdownStep>[];
    await core.close(onProgress: (s) => steps = s);
    // Diagnóstico: etapa do encerramento que estourou o prazo (ex.: catálogo
    // ainda aberto deixaria a pasta do teste presa).
    final late = [
      for (final s in steps)
        if (s.timedOut) s.id,
    ];
    // ignore: avoid_print
    if (late.isNotEmpty) print('Encerramento: etapas que estouraram o prazo: ${late.join(', ')}');
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
