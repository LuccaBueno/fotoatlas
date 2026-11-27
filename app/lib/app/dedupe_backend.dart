import 'dart:io';

import 'package:fotoatlas_core/fotoatlas_core.dart';

/// O que a tela "Repetidos" precisa do core (Fase 9, ADR 0027). Separado de
/// [AppBackend] para os testes antigos não precisarem implementar.
abstract interface class DedupeBackend {
  /// Arquivos ou operações mudaram (os grupos podem ter mudado).
  Stream<void> changes();
  Future<List<DedupeSourceSummary>> summaries();
  Future<List<DedupeGroup>> groups(String sourceId, KeepRule rule);
  Future<KeepRule> keepRule();
  Future<void> setKeepRule(KeepRule rule);

  /// Prévia: só lê (regra 6).
  Future<DedupePreview> preview(String sourceId, List<DedupeChoice> choices);

  /// Confirma a prévia e põe a limpeza na fila. Devolve o id da operação.
  Future<String> start(DedupePreview preview);
  Stream<CopyProgress> get progress;
  Future<void> pause(String operationId);
  Future<void> resume(String operationId);
  Future<void> cancel(String operationId);
  Future<int> retryFailed(String operationId);

  /// Abre o arquivo no programa padrão do Windows (só leitura para o FotoAtlas).
  Future<void> openFile(String path);

  /// Abre o Explorador com o arquivo selecionado.
  Future<void> showInFolder(String path);
}

class CoreDedupeBackend implements DedupeBackend {
  CoreDedupeBackend(this.core);
  final FotoAtlasCore core;

  @override
  Stream<void> changes() => core.dedupe.changes;

  @override
  Future<List<DedupeSourceSummary>> summaries() => core.dedupe.summaries();

  @override
  Future<List<DedupeGroup>> groups(String sourceId, KeepRule rule) => core.dedupe.groups(sourceId, rule: rule);

  @override
  Future<KeepRule> keepRule() => core.dedupe.keepRule();

  @override
  Future<void> setKeepRule(KeepRule rule) => core.dedupe.setKeepRule(rule);

  @override
  Future<DedupePreview> preview(String sourceId, List<DedupeChoice> choices) => core.dedupe.preview(sourceId, choices);

  @override
  Future<String> start(DedupePreview preview) => core.dedupe.start(preview);

  @override
  Stream<CopyProgress> get progress => core.dedupe.progress;

  @override
  Future<void> pause(String operationId) => core.dedupe.pause(operationId);

  @override
  Future<void> resume(String operationId) => core.dedupe.resume(operationId);

  @override
  Future<void> cancel(String operationId) => core.dedupe.cancel(operationId);

  @override
  Future<int> retryFailed(String operationId) => core.dedupe.retryFailed(operationId);

  @override
  Future<void> openFile(String path) => Process.start('explorer.exe', [path]);

  @override
  Future<void> showInFolder(String path) => Process.start('explorer.exe', ['/select,', path]);
}
