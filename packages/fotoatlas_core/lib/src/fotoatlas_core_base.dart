import 'dart:io';

import 'catalog/catalog.dart';
import 'helper/helper_client.dart';
import 'scan/scan_service.dart';
import 'sources/sources_service.dart';
import 'sources/volumes.dart';
import 'util/instance_lock.dart';
import 'util/paths.dart';

/// Fachada do core usada pelo app e pela CLI (`docs/arquitetura.md` §3.1).
class FotoAtlasCore {
  FotoAtlasCore._({
    required this.paths,
    required this.catalog,
    required this.sources,
    required this.scans,
    required this.volumes,
    required this.helper,
    required this._lock,
  });

  final CorePaths paths;
  final Catalog catalog;
  final SourcesService sources;
  final ScanService scans;
  final VolumeProvider volumes;

  /// `null` se o helper não foi encontrado ou não iniciou (o core segue
  /// funcionando com a listagem de volumes via Win32, sem discos físicos).
  final HelperClient? helper;
  final InstanceLock _lock;

  /// Abre o core.
  ///
  /// - [volumes]: provedor explícito (testes). Sem ele, usa o helper em
  ///   [helperPath] (ou [HelperClient.locate]) com reserva Win32.
  /// - [monitor]: verifica a conectividade das fontes a cada 3 s.
  static Future<FotoAtlasCore> open({
    CorePaths? paths,
    VolumeProvider? volumes,
    PathResolver? pathResolver,
    String? helperPath,
    bool useHelper = true,
    bool monitor = false,
    bool scanInIsolate = true,
  }) async {
    final resolvedPaths = paths ?? CorePaths.fromEnvironment();
    Directory(resolvedPaths.dataDir).createSync(recursive: true);
    final lock = await InstanceLock.acquire(resolvedPaths.lockPath);
    Catalog? catalog;
    HelperClient? helper;
    try {
      catalog = await Catalog.open(resolvedPaths.catalogPath);
      var provider = volumes;
      if (provider == null) {
        final win32 = Win32VolumeProvider();
        final exe = useHelper ? (helperPath ?? HelperClient.locate()) : null;
        if (exe != null) {
          helper = HelperClient(executable: exe, cacheDir: resolvedPaths.thumbsDir);
          try {
            await helper.start();
          } on Object {
            // Segue sem helper; o cliente continua tentando reiniciar.
          }
          provider = HelperVolumeProvider(helper, fallback: win32);
        } else {
          provider = win32;
        }
      }
      final sources = SourcesService(catalog.db, provider, resolver: pathResolver);
      await sources.init();
      final scans = ScanService(catalog, sources, useIsolate: scanInIsolate);
      await scans.init();
      await sources.refreshConnectivity();
      if (monitor) sources.startMonitoring();
      return FotoAtlasCore._(
        paths: resolvedPaths,
        catalog: catalog,
        sources: sources,
        scans: scans,
        volumes: provider,
        helper: helper,
        lock: lock,
      );
    } catch (_) {
      await helper?.close();
      await catalog?.close();
      await lock.release();
      rethrow;
    }
  }

  Future<void> close() async {
    sources.stopMonitoring();
    await scans.dispose();
    await sources.dispose();
    await helper?.close();
    await catalog.close();
    await _lock.release();
  }
}
