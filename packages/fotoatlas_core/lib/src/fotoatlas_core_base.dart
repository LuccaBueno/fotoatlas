import 'dart:async';
import 'dart:io';

import 'catalog/catalog.dart';
import 'catalog/catalog_backup.dart';
import 'compare/compare_service.dart';
import 'coverage/coverage_service.dart';
import 'devices/devices.dart';
import 'hash/hash_service.dart';
import 'helper/helper_client.dart';
import 'library/library_service.dart';
import 'metadata/dates_service.dart';
import 'metadata/external_tools.dart';
import 'metadata/metadata_service.dart';
import 'metadata/moments_service.dart';
import 'ops/copy_planner.dart';
import 'ops/copy_service.dart';
import 'scan/scan_service.dart';
import 'sources/sources_service.dart';
import 'sources/volumes.dart';
import 'thumbs/thumbnail_service.dart';
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
    required this.metadata,
    required this.moments,
    required this.dates,
    required this.library,
    required this.thumbnails,
    required this.volumes,
    required this.helper,
    required this.copies,
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

  /// Leitura de metadados (ExifTool/ffprobe) e datas da captura.
  final MetadataService metadata;

  /// Momentos automáticos e edições.
  final MomentsService moments;

  /// Correção de relógio por dispositivo, hora manual e "confirmar hora".
  final DatesService dates;

  /// Consultas da Biblioteca (filtros, linha do tempo, detalhes, seleção).
  final LibraryService library;

  /// Cópia segura com diário e recuperação (Fase 5).
  final CopyService copies;

  /// Miniaturas em cache.
  final ThumbnailService thumbnails;
  final VolumeProvider volumes;

  /// `null` se o helper não foi encontrado ou não iniciou (o core segue
  /// funcionando com a listagem de volumes via Win32, sem discos físicos).
  final HelperClient? helper;

  /// Situação do helper (ex.: `restarting` quando ele caiu e está voltando),
  /// para a interface avisar. Vazio sem helper.
  Stream<HelperStatus> get helperStatus => helper?.statusChanges ?? const Stream.empty();
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
  /// - [helperClient]: cliente do helper já montado (testes com um helper
  ///   falso); o core o inicia se preciso e o encerra no [close].
  /// - [fakeDevicesDir] (ou `FOTOATLAS_FAKE_DEVICES`): o helper mostra os
  ///   celulares simulados dessa pasta em vez dos reais (testes e demonstração).
  /// - [tools]: ExifTool/ffprobe/ffmpeg (padrão: [ExternalTools.locate]).
  /// - [autoMetadata]: lê os metadados sozinho depois da conferência e quando
  ///   uma fonte conecta (o app liga).
  static Future<FotoAtlasCore> open({
    CorePaths? paths,
    VolumeProvider? volumes,
    PathResolver? pathResolver,
    String? helperPath,
    HelperClient? helperClient,
    bool useHelper = true,
    bool monitor = false,
    bool scanInIsolate = true,
    bool hashInIsolate = true,
    bool autoHash = false,
    bool backupOnOpen = false,
    DeviceBackend? devices,
    String? fakeDevicesDir,
    ExternalTools? tools,
    bool autoMetadata = false,
    bool recover = true,
    bool copyInIsolate = true,
    FreeSpaceProbe? freeSpace,
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
      if (helperClient != null) {
        helper = helperClient;
        if (helper.status == HelperStatus.stopped) await helper.start();
        provider ??= HelperVolumeProvider(helper, fallback: Win32VolumeProvider());
        deviceBackend ??= HelperDeviceBackend(helper);
      }
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
      final externalTools = tools ?? ExternalTools.locate();
      final metadata = MetadataService(
        catalog,
        sources,
        scans,
        hashes,
        tools: externalTools,
        cacheDir: resolvedPaths.thumbsDir,
      );
      await metadata.init();
      metadata.cleanLeftovers();
      final moments = MomentsService(catalog.db);
      await moments.init();
      // Regras de data novas: os momentos acompanham (em segundo plano).
      if (metadata.reresolvedOnInit) unawaited(moments.recompute().then((_) {}, onError: (Object _) {}));
      await sources.refreshConnectivity();
      final copies = CopyService(catalog.db, sources, useIsolate: copyInIsolate, freeSpace: freeSpace);
      // Recuperação idempotente das cópias interrompidas (spec §11.2), antes
      // de qualquer outra tarefa: olha o disco e termina o que ficou no meio.
      if (recover) await copies.recoverAll();
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
        metadata: metadata,
        moments: moments,
        dates: DatesService(catalog.db, metadata.effective, moments),
        library: LibraryService(catalog.db),
        thumbnails: ThumbnailService(
          catalog.db,
          sources,
          cacheDir: resolvedPaths.thumbsDir,
          helper: helper,
          tools: externalTools,
        ),
        volumes: provider,
        helper: helper,
        copies: copies,
        lock: lock,
      );
      if (backupOnOpen) {
        // Em segundo plano; uma falha aqui não impede o app de abrir.
        core._backupOnOpen = core.backups
            .maybeBackup()
            .then((_) {}, onError: (Object _) {})
            .whenComplete(() => core._backupDone = true);
      }
      // Datas mudaram (metadados lidos, fuso, prioridade): recalcula os
      // momentos, agrupando rajadas de mudanças.
      core._datesSub = metadata.datesChanged.listen((_) {
        core._momentsTimer?.cancel();
        core._momentsTimer = Timer(const Duration(seconds: 2), () => moments.recompute().ignore());
      });
      if (autoHash) hashes.enableAuto();
      if (autoMetadata) metadata.enableAuto();
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
  StreamSubscription<void>? _datesSub;
  Timer? _momentsTimer;

  /// Espera a leitura de metadados terminar e recalcula os momentos na hora
  /// (testes, CLI e "Atualizar").
  Future<MomentsRecalc> settleDates() async {
    await metadata.waitIdle();
    _momentsTimer?.cancel();
    return moments.recompute();
  }

  /// O que está em andamento agora (para perguntar antes de fechar).
  Future<List<RunningTask>> runningTasks() async {
    final tasks = <RunningTask>[];
    if (copies.isRunning) {
      final c = copies.current;
      tasks.add(RunningTask(RunningTaskKind.copy, done: c?.itemsDone ?? 0, total: c?.itemsTotal ?? 0));
    }
    final scansNow = scans.runningProgress.values.toList();
    if (scansNow.isNotEmpty) {
      final names = {for (final s in await catalog.db.select(catalog.db.sources).get()) s.id: s.name};
      for (final p in scansNow) {
        tasks.add(RunningTask(RunningTaskKind.scan, sourceName: names[p.sourceId], done: p.filesSeen));
      }
    }
    if (hashes.isRunning) {
      final h = hashes.current;
      tasks.add(RunningTask(RunningTaskKind.hash, done: h.filesDone, total: h.filesTotal));
    }
    if (metadata.isRunning) {
      final m = metadata.current;
      tasks.add(RunningTask(RunningTaskKind.metadata, done: m.done, total: m.total));
    }
    if (_backupOnOpen != null && !_backupDone) tasks.add(const RunningTask(RunningTaskKind.backup));
    return tasks;
  }

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
      if (copies.isRunning)
        ShutdownStep('copy', 'Pausando a cópia (o arquivo do momento volta para a fila; nada se perde)'),
      if (runningScans > 0)
        ShutdownStep(
          'scan',
          runningScans == 1
              ? 'Pausando o escaneamento (o ponto de parada fica salvo)'
              : 'Pausando $runningScans escaneamentos (o ponto de parada fica salvo)',
        ),
      if (hashes.isRunning) ShutdownStep('hash', 'Pausando a conferência de conteúdo (o que falta continua na fila)'),
      if (metadata.isRunning)
        ShutdownStep('metadata', 'Pausando a leitura das datas e informações das fotos (o que falta continua na fila)'),
      if (_backupOnOpen != null && !_backupDone) ShutdownStep('backup', 'Terminando o backup do catálogo'),
      if (helper != null) ShutdownStep('helper', 'Encerrando a leitura de dispositivos'),
      ShutdownStep('catalog', 'Fechando o catálogo'),
    ];
    void report() => onProgress?.call(List.unmodifiable(steps));

    /// `true` se a etapa terminou dentro do prazo.
    /// [action] pode devolver `false` para dizer que não terminou tudo a tempo.
    Future<bool> step(String id, Future<Object?> Function() action, {Duration? timeout}) async {
      final s = steps.where((s) => s.id == id).firstOrNull;
      var ok = true;
      try {
        ok = await action().timeout(timeout ?? stepTimeout) != false;
      } on Object {
        // Prazo estourado ou erro: segue; o que ficou pela metade é recuperável.
        ok = false;
      }
      if (s != null) {
        s.done = true;
        s.timedOut = !ok;
        report();
      }
      return ok;
    }

    report();
    unawaited(_datesSub?.cancel());
    _momentsTimer?.cancel();
    thumbnails.close();
    await Future.wait([
      step('copy', () => copies.dispose(timeout: stepTimeout)),
      step('scan', () => scans.dispose(timeout: stepTimeout)),
      step('hash', () => hashes.dispose(timeout: stepTimeout)),
      // Também fecha o ExifTool; um recálculo de momentos em andamento termina numa transação.
      step('metadata', () async {
        final ok = await metadata.dispose(timeout: stepTimeout);
        await moments.waitIdle();
        return ok;
      }),
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

  /// A etapa estourou o prazo (ou deu erro) e o encerramento seguiu sem ela.
  bool timedOut = false;
}

enum RunningTaskKind { copy, scan, hash, metadata, backup }

/// Uma tarefa em andamento. [done]/[total]: arquivos encontrados (scan) ou
/// conferidos (conferência); `total` 0 = desconhecido.
class RunningTask {
  const RunningTask(this.kind, {this.sourceName, this.done = 0, this.total = 0});
  final RunningTaskKind kind;
  final String? sourceName;
  final int done;
  final int total;
}
