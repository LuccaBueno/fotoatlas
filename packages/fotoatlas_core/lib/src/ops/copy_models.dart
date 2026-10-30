import 'dart:typed_data';

import 'names.dart';

/// Estados de um item no diário (`docs/arquitetura.md` §3.6).
abstract final class ItemState {
  static const pending = 'pending';
  static const copying = 'copying';
  static const copied = 'copied';
  static const verifying = 'verifying';
  static const verified = 'verified';
  static const publishing = 'publishing';
  static const published = 'published';
  static const skippedIdentical = 'skipped_identical';
  static const failed = 'failed';
  static const needsAttention = 'needs_attention';

  /// Estados finais: nada mais acontece com o item sem um pedido do usuário.
  static const finals = {published, skippedIdentical, failed, needsAttention, 'undone'};

  /// Em andamento: a recuperação precisa olhar o disco.
  static const inFlight = {copying, copied, verifying, verified, publishing};
}

/// Estados de uma operação.
abstract final class OpStatus {
  static const confirmed = 'confirmed';
  static const running = 'running';
  static const paused = 'paused';
  static const completed = 'completed';
  static const completedWithErrors = 'completed_with_errors';
  static const cancelled = 'cancelled';
  static const needsAttention = 'needs_attention';

  static const open = {confirmed, running, paused, needsAttention};
}

enum ConflictPolicy {
  /// Nome já usado no destino: `IMG_1.jpg`, `IMG_2.jpg`… (padrão).
  suffix,

  /// Pergunta: o item fica "precisa de atenção" e a pessoa decide na tela Tarefas.
  ask,
}

/// O que copiar e para onde (assistente "Copiar o que falta").
class CopyRequest {
  const CopyRequest({
    required this.contentIds,
    required this.destSourceId,
    this.destFolder = '',
    this.template = '{ano}/{ano}-{mes}',
    this.conflict = ConflictPolicy.suffix,
    this.preferSourceIds = const [],
    this.origin,
    this.toConfirmFolder = undatedFolder,
    this.fileNames = const {},
  });

  /// Conteúdos escolhidos (Comparar ou Biblioteca).
  final List<int> contentIds;
  final String destSourceId;

  /// Pasta dentro do destino, relativa à raiz dele (`/`), `''` = raiz.
  final String destFolder;

  /// Modelo de organização (`FolderTemplate`).
  final String template;
  final ConflictPolicy conflict;

  /// Fontes preferidas para ler (ex.: o lado A da comparação).
  final List<String> preferSourceIds;

  /// De onde veio o pedido (`compare`, `library`, `cli`), para o histórico.
  final String? origin;

  /// Pasta dos itens sem data (ou fora de momentos, no modelo por momento).
  final String toConfirmFolder;

  /// Nome do arquivo no destino por conteúdo, no lugar do nome da origem
  /// (restaurar: o nome do arquivo danificado, com sufixo se ocupado).
  final Map<int, String> fileNames;
}

/// Um arquivo da prévia.
class PlannedCopy {
  const PlannedCopy({
    required this.contentId,
    required this.instanceId,
    required this.srcSourceId,
    required this.srcRelPath,
    required this.size,
    required this.sha256,
    required this.mtime,
    required this.dstRelPath,
    this.originalName,
    this.renamedForConflict = false,
    this.askConflict = false,
    this.lowConfidenceDate = false,
    this.undated = false,
  });

  final int contentId;
  final int instanceId;
  final String srcSourceId;
  final String srcRelPath;
  final int size;
  final Uint8List? sha256;
  final int? mtime;

  /// Caminho planejado no destino, relativo à raiz da fonte de destino.
  final String dstRelPath;

  /// Nome original, quando a sanitização mudou o nome.
  final String? originalName;

  /// Já existe um arquivo com esse nome no destino: ganhou sufixo.
  final bool renamedForConflict;

  /// Já existe um arquivo com esse nome e a política é perguntar.
  final bool askConflict;
  final bool lowConfidenceDate;
  final bool undated;
}

/// Conteúdo que não pode ser copiado agora, e por quê.
class UnavailableCopy {
  const UnavailableCopy(this.contentId, this.name, this.reason);
  final int contentId;
  final String name;
  final String reason;
}

/// Pasta da prévia da estrutura.
class PlannedFolder {
  const PlannedFolder(this.relPath, this.files, this.bytes);
  final String relPath;
  final int files;
  final int bytes;
}

/// Prévia: tudo o que vai acontecer, antes de confirmar (regra 6).
class CopyPreview {
  const CopyPreview({
    required this.request,
    required this.destName,
    required this.destDisplay,
    required this.destFileSystem,
    required this.items,
    required this.alreadyThere,
    required this.alreadyThereBytes,
    required this.unavailable,
    required this.tooLargeForFat32,
    required this.freeBytes,
    required this.reserveBytes,
    required this.folders,
    this.blocker,
  });

  final CopyRequest request;
  final String destName;

  /// Ex.: `E:\Backup` (ou o nome do volume, sem letra).
  final String? destDisplay;
  final String? destFileSystem;
  final List<PlannedCopy> items;

  /// Conteúdos que o destino já tem (em qualquer pasta): não são copiados.
  final int alreadyThere;
  final int alreadyThereBytes;
  final List<UnavailableCopy> unavailable;

  /// Arquivos acima de 4 GB com destino FAT32: ficam de fora.
  final List<UnavailableCopy> tooLargeForFat32;

  /// `null` = não foi possível saber.
  final int? freeBytes;

  /// Margem que fica livre no destino.
  final int reserveBytes;
  final List<PlannedFolder> folders;

  /// Motivo que impede começar (destino desconectado, etc.).
  final String? blocker;

  int get totalBytes => items.fold(0, (s, i) => s + i.size);
  int get renamedForConflict => items.where((i) => i.renamedForConflict).length;
  int get askConflicts => items.where((i) => i.askConflict).length;
  int get sanitized => items.where((i) => i.originalName != null).length;
  int get lowConfidence => items.where((i) => i.lowConfidenceDate).length;
  int get undated => items.where((i) => i.undated).length;

  /// Espaço suficiente (ou desconhecido: a checagem por arquivo protege).
  bool get enoughSpace => freeBytes == null || freeBytes! >= totalBytes + reserveBytes;
  bool get canStart => blocker == null && items.isNotEmpty && enoughSpace;
}

/// Progresso da operação em andamento.
class CopyProgress {
  const CopyProgress({
    required this.operationId,
    required this.itemsDone,
    required this.itemsTotal,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentName,
    this.currentBytes = 0,
    this.currentSize = 0,
    this.step,
    this.running = true,
  });

  final String operationId;
  final int itemsDone;
  final int itemsTotal;
  final int bytesDone;
  final int bytesTotal;
  final String? currentName;
  final int currentBytes;
  final int currentSize;

  /// `copying`, `verifying` ou `publishing`.
  final String? step;
  final bool running;
}

/// Uma operação para a tela Tarefas.
class OperationView {
  const OperationView({
    required this.id,
    required this.kind,
    required this.status,
    required this.destSourceId,
    required this.destName,
    required this.destFolder,
    required this.template,
    required this.createdAt,
    required this.counts,
    required this.totalItems,
    required this.totalBytes,
    required this.doneBytes,
    this.startedAt,
    this.finishedAt,
    this.pauseReason,
    this.origin,
    this.undoOf,
  });

  final String id;
  final String kind;
  final String status;
  final String? destSourceId;
  final String destName;
  final String destFolder;
  final String? template;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  /// Itens por estado.
  final Map<String, int> counts;
  final int totalItems;
  final int totalBytes;

  /// Bytes dos itens já publicados ou que o destino já tinha.
  final int doneBytes;
  final String? pauseReason;
  final String? origin;

  int count(String state) => counts[state] ?? 0;
  int get published => count(ItemState.published);
  int get skipped => count(ItemState.skippedIdentical);
  int get failed => count(ItemState.failed);
  int get needsAttention => count(ItemState.needsAttention);

  /// Reorganização: itens já devolvidos pelo Desfazer.
  int get undone => count('undone');
  int get remaining => totalItems - published - skipped - failed - needsAttention - undone;

  /// Desfazer: a reorganização que esta operação desfaz.
  final String? undoOf;
  bool get isOpen => OpStatus.open.contains(status);
}

/// Um item para os detalhes da tela Tarefas.
class OperationItemView {
  const OperationItemView({
    required this.id,
    required this.seq,
    required this.state,
    required this.srcSourceId,
    required this.srcRelPath,
    required this.dstRelPath,
    required this.size,
    this.errorCode,
    this.errorMessage,
    this.originalName,
  });
  final int id;
  final int seq;
  final String state;
  final String srcSourceId;
  final String srcRelPath;

  /// Final se já publicado; senão o planejado.
  final String dstRelPath;
  final int size;
  final String? errorCode;
  final String? errorMessage;

  /// Nome na origem quando foi ajustado para o Windows aceitar.
  final String? originalName;

  /// Nome do arquivo na origem.
  String get srcName => srcRelPath.split('/').last;

  /// Nome com que foi (ou vai ser) salvo no destino.
  String get dstName => dstRelPath.split('/').last;

  /// Salvo com outro nome (`_1`, `_2`…) porque o nome já existia no destino.
  bool get renamedForConflict => state == ItemState.published && dstName != sanitizeName(srcName);
}

/// Arquivo na pasta temporária do destino que não pertence a nenhuma cópia em
/// andamento. Nunca é apagado automaticamente (spec §11.2).
class TempLeftover {
  const TempLeftover({required this.name, required this.size, required this.modified, this.note});
  final String name;
  final int size;
  final DateTime modified;

  /// Ex.: "guardado para diagnóstico (a conferência não bateu)".
  final String? note;
}

/// Resultado de uma rodada de recuperação.
class RecoveryReport {
  RecoveryReport();
  int examined = 0;
  int resumedAsPending = 0;
  int verified = 0;
  int published = 0;
  int needsAttention = 0;
  int skippedDestUnavailable = 0;

  bool get changedSomething => resumedAsPending + verified + published + needsAttention > 0;

  @override
  String toString() =>
      'examinados=$examined refazer=$resumedAsPending conferidos=$verified publicados=$published '
      'atencao=$needsAttention destino_indisponivel=$skippedDestUnavailable';
}
