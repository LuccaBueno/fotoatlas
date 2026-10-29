import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../sources/volumes.dart';

const int helperProtocolVersion = 1;

/// Erro devolvido pelo helper ou pelo cliente (`docs/protocolo-helper.md` §4).
class HelperException implements Exception {
  HelperException(this.code, this.message, {this.retryable = false});
  final String code;
  final String message;
  final bool retryable;

  @override
  String toString() => 'HelperException($code): $message';
}

enum HelperStatus { stopped, starting, ready, restarting }

/// Evento emitido pelo helper (com `id` quando ligado a um pedido).
class HelperEvent {
  const HelperEvent(this.name, this.data, {this.requestId});
  final String name;
  final Map<String, Object?> data;
  final String? requestId;
}

/// Cliente JSON-lines do `fotoatlas_helper.exe`, com reinício automático.
///
/// Se o processo cai ou para de responder ao ping, os pedidos em voo falham
/// com `helper_crashed` (tratado como falha de leitura, nunca como ausência)
/// e o helper é reiniciado com espera crescente (1, 2, 4… até 30 s).
class HelperClient {
  HelperClient({
    required this.executable,
    this.arguments = const [],
    this.cacheDir,
    this.requestTimeout = const Duration(seconds: 30),
    this.pingInterval = const Duration(seconds: 5),
    this.pingTimeout = const Duration(seconds: 10),
    this.maxBackoff = const Duration(seconds: 30),
  });

  /// Executável do helper (ou outro programa que fale o protocolo, em testes).
  final String executable;

  /// Argumentos extras antes dos argumentos do protocolo.
  final List<String> arguments;
  final String? cacheDir;
  final Duration requestTimeout;
  final Duration pingInterval;
  final Duration pingTimeout;
  final Duration maxBackoff;

  Process? _process;
  int? _pid;

  /// PID do último processo do helper iniciado (diagnóstico e testes).
  int? get pid => _pid;
  int _nextId = 1;
  final _pending = <String, Completer<Map<String, Object?>>>{};
  final _eventHandlers = <String, void Function(HelperEvent)>{};
  final _events = StreamController<HelperEvent>.broadcast();
  final _statusController = StreamController<HelperStatus>.broadcast();
  HelperStatus _status = HelperStatus.stopped;
  Completer<void>? _hello;
  Timer? _pingTimer;
  Timer? _restartTimer;
  Duration _backoff = const Duration(seconds: 1);
  bool _closing = false;
  int _restarts = 0;

  Stream<HelperEvent> get events => _events.stream;
  Stream<HelperStatus> get statusChanges => _statusController.stream;
  HelperStatus get status => _status;

  /// Quantas vezes o helper foi reiniciado após falha.
  int get restarts => _restarts;

  /// Inicia o helper e espera o `hello`.
  Future<void> start() async {
    _closing = false;
    await _spawn();
  }

  Future<void> _spawn() async {
    _setStatus(_restarts == 0 ? HelperStatus.starting : HelperStatus.restarting);
    final hello = _hello = Completer<void>();
    final args = [
      ...arguments,
      '--protocol',
      '$helperProtocolVersion',
      '--parent-pid',
      '$pid',
      if (cacheDir != null) ...['--cache-dir', cacheDir!],
    ];
    final process = await Process.start(executable, args);
    _process = process;
    _pid = process.pid;
    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine, onError: (_) {});
    process.stderr.drain<void>().ignore();
    process.exitCode.then((_) => _onExit(process));

    try {
      await hello.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      process.kill();
      throw HelperException('helper_crashed', 'O helper não respondeu ao iniciar.', retryable: true);
    }
    _backoff = const Duration(seconds: 1);
    _setStatus(HelperStatus.ready);
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(pingInterval, (_) => _ping(process));
  }

  Future<void> _ping(Process process) async {
    if (_process != process || _status != HelperStatus.ready) return;
    try {
      await call('system.ping', timeout: pingTimeout);
    } on HelperException catch (e) {
      if (e.code == 'timeout' && _process == process) process.kill();
    }
  }

  void _onLine(String line) {
    final Map<String, Object?> message;
    try {
      message = (jsonDecode(line) as Map).cast<String, Object?>();
    } on Object {
      return; // linha inválida: ignorada (o helper só deve escrever JSON).
    }
    final event = message['event'] as String?;
    final id = message['id'] as String?;
    if (event != null) {
      final data = (message['data'] as Map?)?.cast<String, Object?>() ?? const {};
      if (event == 'hello' && id == null) {
        final protocol = (data['protocol'] as num?)?.toInt();
        final hello = _hello;
        if (hello != null && !hello.isCompleted) {
          if (protocol == helperProtocolVersion) {
            hello.complete();
          } else {
            hello.completeError(
              HelperException(
                'protocol_mismatch',
                'Helper fala o protocolo $protocol; esperado $helperProtocolVersion.',
              ),
            );
          }
        }
        return;
      }
      final helperEvent = HelperEvent(event, data, requestId: id);
      if (id != null) _eventHandlers[id]?.call(helperEvent);
      if (!_events.isClosed) _events.add(helperEvent);
      return;
    }
    if (id == null) return;
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    if (message['ok'] == true) {
      completer.complete((message['result'] as Map?)?.cast<String, Object?>() ?? const {});
    } else {
      final error = (message['error'] as Map?)?.cast<String, Object?>() ?? const {};
      completer.completeError(
        HelperException(
          error['code'] as String? ?? 'internal',
          error['message'] as String? ?? '',
          retryable: error['retryable'] as bool? ?? false,
        ),
      );
    }
  }

  void _onExit(Process process) {
    if (_process != process) return;
    _process = null;
    _pingTimer?.cancel();
    final hello = _hello;
    if (hello != null && !hello.isCompleted) {
      hello.completeError(HelperException('helper_crashed', 'O helper encerrou ao iniciar.', retryable: true));
    }
    _failAll(HelperException('helper_crashed', 'O helper encerrou inesperadamente.', retryable: true));
    if (_closing) {
      _setStatus(HelperStatus.stopped);
      return;
    }
    _scheduleRestart();
  }

  void _scheduleRestart() {
    _setStatus(HelperStatus.restarting);
    final delay = _backoff;
    final next = _backoff * 2;
    _backoff = next > maxBackoff ? maxBackoff : next;
    _restartTimer?.cancel();
    _restartTimer = Timer(delay, () async {
      if (_closing) return;
      _restarts++;
      try {
        await _spawn();
      } on HelperException catch (e) {
        if (e.code == 'protocol_mismatch') {
          _setStatus(HelperStatus.stopped);
          return;
        }
        // _onExit já agenda a próxima tentativa se o processo morreu;
        // se ainda estiver vivo mas mudo, mata e deixa _onExit cuidar.
        _process?.kill();
      } on ProcessException {
        _scheduleRestart();
      }
    });
  }

  /// Envia um pedido e espera a resposta.
  ///
  /// [onEvent] recebe os eventos deste pedido (lotes, progresso). Quando
  /// [cancel] completa, pede `system.cancel` ao helper; o pedido então falha
  /// com `cancelled`.
  Future<Map<String, Object?>> call(
    String method, {
    Map<String, Object?> params = const {},
    Duration? timeout,
    void Function(HelperEvent event)? onEvent,
    Future<void>? cancel,
  }) {
    final process = _process;
    if (process == null || _status != HelperStatus.ready) {
      return Future.error(HelperException('helper_unavailable', 'O helper não está em execução.', retryable: true));
    }
    final id = '${_nextId++}';
    final completer = Completer<Map<String, Object?>>();
    _pending[id] = completer;
    if (onEvent != null) _eventHandlers[id] = onEvent;
    process.stdin.write('${jsonEncode({'v': helperProtocolVersion, 'id': id, 'method': method, 'params': params})}\n');
    cancel?.then((_) {
      if (_pending.containsKey(id) && _process == process) {
        call('system.cancel', params: {'target': id}).ignore();
      }
    });
    return completer.future
        .whenComplete(() => _eventHandlers.remove(id))
        .timeout(
          timeout ?? requestTimeout,
          onTimeout: () {
            _pending.remove(id);
            _eventHandlers.remove(id);
            throw HelperException('timeout', 'O helper não respondeu a "$method" a tempo.', retryable: true);
          },
        );
  }

  void _failAll(HelperException error) {
    final pending = Map.of(_pending);
    _pending.clear();
    _eventHandlers.clear();
    for (final c in pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
  }

  void _setStatus(HelperStatus status) {
    if (_status == status) return;
    _status = status;
    if (!_statusController.isClosed) _statusController.add(status);
  }

  /// Encerra o helper: pede `system.shutdown` e, se ele não sair em
  /// [grace] (ex.: preso numa leitura do celular), finaliza o processo.
  /// Termina sempre, em no máximo ~2 × [grace] + 1 s.
  Future<void> close({Duration grace = const Duration(seconds: 1)}) async {
    _closing = true;
    _restartTimer?.cancel();
    _pingTimer?.cancel();
    final process = _process;
    if (process != null) {
      try {
        await call('system.shutdown', timeout: grace);
      } on Object {
        // segue para o kill
      }
      try {
        await process.stdin.close().timeout(const Duration(milliseconds: 200));
      } on Object {
        // stdin já fechado ou preso
      }
      final exited = await process.exitCode.then((_) => true).timeout(grace, onTimeout: () => false);
      if (!exited) {
        process.kill();
        await process.exitCode.timeout(const Duration(seconds: 1), onTimeout: () => -1);
      }
      _failAll(HelperException('helper_closed', 'O FotoAtlas está fechando.', retryable: false));
    }
    _setStatus(HelperStatus.stopped);
    // Sem `await`: um ouvinte pausado (ex.: tela fora de vista) faria o
    // close() nunca terminar e o app não fecharia.
    unawaited(_events.close());
    unawaited(_statusController.close());
  }

  /// Procura o helper: `FOTOATLAS_HELPER`, ao lado do executável, ou a saída
  /// de build em `native/fotoatlas_helper` subindo a partir de [startDir].
  static String? locate({String? startDir}) {
    final env = Platform.environment['FOTOATLAS_HELPER'];
    if (env != null && File(env).existsSync()) return env;
    const exe = 'fotoatlas_helper.exe';
    final exeDir = p.dirname(Platform.resolvedExecutable);
    for (final candidate in [p.join(exeDir, exe), p.join(exeDir, 'helper', exe)]) {
      if (File(candidate).existsSync()) return candidate;
    }
    var dir = Directory(startDir ?? Directory.current.path).absolute;
    for (var i = 0; i < 8; i++) {
      for (final config in ['Release', 'Debug']) {
        final candidate = p.join(
          dir.path,
          'native',
          'fotoatlas_helper',
          'FotoAtlas.Helper',
          'bin',
          config,
          'net10.0-windows',
          exe,
        );
        if (File(candidate).existsSync()) return candidate;
      }
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    return null;
  }
}

/// Volumes pelo helper; se ele não estiver disponível, usa [fallback].
class HelperVolumeProvider implements VolumeProvider {
  HelperVolumeProvider(this.client, {this._fallback});

  final HelperClient client;
  final VolumeProvider? _fallback;

  @override
  Future<List<VolumeInfo>> list() async {
    try {
      final result = await client.call('volumes.list');
      return [
        for (final v in result['volumes'] as List<Object?>? ?? const [])
          VolumeInfo.fromJson((v as Map).cast<String, Object?>()),
      ];
    } on HelperException {
      final fallback = _fallback;
      if (fallback == null) rethrow;
      return fallback.list();
    }
  }
}
