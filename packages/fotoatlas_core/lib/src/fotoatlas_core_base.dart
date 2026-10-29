import 'dart:async';
import 'dart:io';

import 'catalog/catalog.dart';
import 'catalog/catalog_backup.dart';
import 'compare/compare_service.dart';
import 'coverage/coverage_service.dart';
import 'devices/devices.dart';
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
  /// - [devices]: celulares explícitos (testes). Sem ele, usa o helper.
  /// - [fakeDevicesDir] (ou `FOTOATLAS_FAKE_DEVICES`): o helper mostra os
  ///   celulares simulados dessa pasta em vez dos reais (testes e demonstração).
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
    DeviceBackend? devices,
    String? fakeDevicesDir,
  }) async {
    final resolvedPaths = paths ?? CorePaths.fromEnvironment();
    Directory(resolvedPaths.dataDir).createSync(recursive: true);
    final lock = await InstanceLock.acquire(resolvedPaths.lockPath);
    Catalog? catalog;
    HelperClient? helper;
    var deviceBackend = devices;
    final fake = fakeDevicesDir ?? Platform.environment['FOTOATLAS_FAKE_DEVICES'];
    try {
      catalog = await Catalog.open(resolvedPaths.catalogPath);
      var provider = volumes;
      if (provider == null) {
        final win32 = Win32VolumeProvider();
        final exe = useHelper ? (helperPath ?? HelperClient.locate()) : null;
        if (exe != null) {
          helper = HelperClient(
            executable: exe,
            cacheDir: resolvedPaths.thumbsDir,
            arguments: [
              if (fake != null && fake.isNotEmpty) ...['--fake-devices', fake],
            ],
          );
          try {
            await helper.start();
          } on Object {
            // Segue sem helper; o cliente continua tentando reiniciar.
          }
          provider = HelperVolumeProvider(helper, fallback: win32);
          deviceBackend ??= HelperDeviceBackend(helper);
        } else {
          provider = win32;
        }
      }
      final sources = SourcesService(catalog.db, provider, resolver: pathResolver, devices: deviceBackend);
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
        core._backupOnOpen = core.backups
            .maybeBackup()
            .then((_) {}, onError: (Object _) {})
            .whenComplete(() => core._backupDone = true);
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

  bool _backupDone = false;
  Future<void>? _closing;

  /// Encerra com segurança e **sempre termina** (em poucos segundos, mesmo
  /// com o helper travado numa leitura do celular). Cada etapa tem prazo:
  ///
  /// 1. pausa os scans (o ponto de parada já está salvo a cada lote) e a fila
  ///    de conferência (o que falta continua `pending`);
  /// 2. espera o backup do catálogo, se estiver no meio;
  /// 3. encerra o helper — se não responder, finaliza o processo dele;
  /// 4. fecha o catálogo.
  ///
  /// O que não terminar a tempo é seguro por construção: scan `running` vira
  /// `interrupted` ao abrir de novo, arquivo sem hash continua pendente e um
  /// backup pela metade (`.tmp`) é descartado (regra 7).
  ///
  /// [onProgress] recebe a lista de etapas com trabalho (para "Encerrando
  /// com segurança…"); chamar de novo devolve o mesmo encerramento.
  Future<void> close({void Function(List<ShutdownStep> steps)? onProgress, Duration stepTimeout = _stepTimeout}) =>
      _closing ??= _close(onProgress, stepTimeout);

  static const _stepTimeout = Duration(seconds: 3);
  static const _catalogTimeout = Duration(seconds: 5);

  Future<void> _close(void Function(List<ShutdownStep>)? onProgress, Duration stepTimeout) async {
    sources.stopMonitoring();
    final runningScans = scans.runningProgress.length;
    final steps = <ShutdownStep>[
      if (runningScans > 0)
        ShutdownStep(
          'scan',
          runningScans == 1
              ? 'Pausando o escaneamento (o ponto de parada fica salvo)'
              : 'Pausando $runningScans escaneamentos (o ponto de parada fica salvo)',
        ),
      if (hashes.isRunning) ShutdownStep('hash', 'Pausando a conferência de conteúdo (o que falta continua na fila)'),
      if (_backupOnOpen != null && !_backupDone) ShutdownStep('backup', 'Terminando o backup do catálogo'),
      if (helper != null) ShutdownStep('helper', 'Encerrando a leitura de dispositivos'),
      ShutdownStep('catalog', 'Fechando o catálogo'),
    ];
    void report() => onProgress?.call(List.unmodifiable(steps));

    /// `true` se a etapa terminou dentro do prazo.
    Future<bool> step(String id, Future<void> Function() action, {Duration? timeout}) async {
      final s = steps.where((s) => s.id == id).firstOrNull;
      var ok = true;
      try {
        await action().timeout(timeout ?? stepTimeout);
      } on Object {
        // Prazo estourado ou erro: segue; o que ficou pela metade é recuperável.
        ok = false;
      }
      if (s != null) {
        s.done = true;
        report();
      }
      return ok;
    }

    report();
    await Future.wait([
      step('scan', () => scans.dispose(timeout: stepTimeout)),
      step('hash', () => hashes.dispose(timeout: stepTimeout)),
    ]);
    await step('backup', () async => _backupOnOpen);
    await step('sources', sources.dispose);
    // O helper tem o próprio prazo (pede para sair; se não sair, é finalizado).
    await step('helper', () async => helper?.close(), timeout: stepTimeout * 2);
    // O catálogo tem prazo próprio, maior: fechar o SQLite é rápido, mas numa
    // máquina lenta pode passar do prazo curto das outras etapas.
    final catalogClosed = await step('catalog', catalog.close, timeout: _catalogTimeout);
    // Catálogo ainda aberto: a trava continua com este processo (que vai
    // sair) para nenhum outro abrir o mesmo arquivo ao mesmo tempo.
    if (catalogClosed) await _lock.release();
  }
}

/// Uma etapa do encerramento, para mostrar o que falta.
class ShutdownStep {
  ShutdownStep(this.id, this.label);
  final String id;
  final String label;
  bool done = false;
}
