import 'dart:async';
import 'dart:io';

import 'catalog/catalog.dart';
import 'catalog/catalog_backup.dart';
import 'compare/compare_service.dart';
import 'coverage/coverage_service.dart';
import 'hash/hash_service.dart';
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
    required this.hashes,
    required this.coverage,
    required this.compare,
    required this.backups,
    required this.volumes,
    required this.helper,
    required this._lock,
  });

  final CorePaths paths;
  final Catalog catalog;
  final SourcesService sources;
  final ScanService scans;

  /// Fila de conferência de conteúdo (SHA-256).
  final HashService hashes;

  /// Duplicatas e níveis de cobertura.
  final CoverageService coverage;

  /// Comparação A × B com escopo livre e escopos salvos.
  final CompareService compare;

  /// Backup automático do catálogo.
  final CatalogBackupService backups;
  final VolumeProvider volumes;

  /// `null` se o helper não foi encontrado ou não iniciou (o core segue
  /// funcionando com a listagem de volumes via Win32, sem discos físicos).
  final HelperClient? helper;
  final InstanceLock _lock;
  Future<void>? _backupOnOpen;

  /// Abre o core.
  ///
  /// - [volumes]: provedor explícito (testes). Sem ele, usa o helper em
  ///   [helperPath] (ou [HelperClient.locate]) com reserva Win32.
  /// - [monitor]: verifica a conectividade das fontes a cada 3 s.
  /// - [autoHash]: confere o conteúdo sozinho depois de cada scan e quando
  ///   uma fonte conecta (o app liga; testes e CLI controlam na mão).
  /// - [backupOnOpen]: faz backup do catálogo se o último tiver mais de 24 h.
  static Future<FotoAtlasCore> open({
    CorePaths? paths,
    VolumeProvider? volumes,
    PathResolver? pathResolver,
    String? helperPath,
    bool useHelper = true,
    bool monitor = false,
    bool scanInIsolate = true,
    bool hashInIsolate = true,
    bool autoHash = false,
    bool backupOnOpen = false,
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
      final hashes = HashService(catalog, sources, scans, useIsolate: hashInIsolate);
      await sources.refreshConnectivity();
      if (monitor) sources.startMonitoring();
      final core = FotoAtlasCore._(
        paths: resolvedPaths,
        catalog: catalog,
        sources: sources,
        scans: scans,
        hashes: hashes,
        coverage: CoverageService(catalog.db),
        compare: CompareService(catalog.db, sources),
        backups: CatalogBackupService(catalog.db, resolvedPaths.catalogPath),
        volumes: provider,
        helper: helper,
        lock: lock,
      );
      if (backupOnOpen) {
        // Em segundo plano; uma falha aqui não impede o app de abrir.
        core._backupOnOpen = core.backups.maybeBackup().then((_) {}, onError: (Object _) {});
      }
      if (autoHash) hashes.enableAuto();
      return core;
    } catch (_) {
      await helper?.close();
      await catalog?.close();
      await lock.release();
      rethrow;
    }
  }

  Future<void> close() async {
    sources.stopMonitoring();
    await _backupOnOpen;
    await hashes.dispose();
    await scans.dispose();
    await sources.dispose();
    await helper?.close();
    await catalog.close();
    await _lock.release();
  }
}
