import 'dart:typed_data';

/// Resultado da verificação de um arquivo (spec §14; valores de
/// `integrity_checks.result`).
abstract final class CheckResult {
  /// Conteúdo idêntico ao conferido antes.
  static const unchanged = 'unchanged';

  /// Conteúdo mudou e a data de modificação também: alguém editou o arquivo.
  static const changedLegit = 'changed_legit';

  /// Conteúdo mudou, mas a data não: sinal de dano no disco.
  static const possiblyCorrupt = 'possibly_corrupt';

  /// Não deu para ler agora (bloqueado, sem permissão, mudou durante a leitura).
  static const unreadable = 'unreadable';

  /// Não está mais no caminho (nunca vira "ausente" por isso, regra 10).
  static const missing = 'missing';

  static const all = [unchanged, changedLegit, possiblyCorrupt, unreadable, missing];
}

/// Diferença exata de 1 hora em FILETIME: o FAT32 guarda a hora local, e a
/// data "anda" 1 h quando muda o horário de verão (`docs/analise-spec.md` C7).
const int fatDstShift = 3600 * 10000000;

/// Classifica um arquivo relido (spec §14 e `docs/analise-spec.md` C7):
/// - mesmo conteúdo → inalterado (mesmo que a data tenha mudado);
/// - conteúdo diferente e data diferente → alterado (editado);
/// - conteúdo diferente com a mesma data (ou exatamente ±1 h num disco FAT)
///   → possivelmente corrompido.
String classifyCheck({
  required Uint8List expectedSha256,
  required int expectedSize,
  required int? expectedMtime,
  required Uint8List observedSha256,
  required int observedSize,
  required int? observedMtime,
  bool fat = false,
}) {
  if (observedSize == expectedSize && _eq(expectedSha256, observedSha256)) return CheckResult.unchanged;
  final sameDate =
      observedMtime == expectedMtime ||
      (fat && observedMtime != null && expectedMtime != null && (observedMtime - expectedMtime).abs() == fatDstShift);
  return sameDate ? CheckResult.possiblyCorrupt : CheckResult.changedLegit;
}

bool _eq(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Um trecho a verificar: uma fonte inteira (`folder` vazio) ou uma pasta.
class VerifyEntry {
  const VerifyEntry(this.sourceId, {this.folder = ''});
  final String sourceId;

  /// Relativa à raiz da fonte, com `/`; `''` = a fonte inteira.
  final String folder;

  Map<String, Object?> toJson() => {'source': sourceId, if (folder.isNotEmpty) 'folder': folder};
}

/// O que verificar.
///
/// Celulares só entram quando aparecem em [entries] (o usuário pediu aquele
/// celular); por [contentIds] (Biblioteca) e no agendamento, nunca.
class VerifyRequest {
  const VerifyRequest({this.entries = const [], this.contentIds = const [], this.olderThanDays});

  final List<VerifyEntry> entries;

  /// Conteúdos escolhidos na Biblioteca: todas as cópias deles nos discos
  /// conectados.
  final List<int> contentIds;

  /// Só os arquivos não conferidos há mais de N dias.
  final int? olderThanDays;
}

/// Quanto uma verificação vai ler (antes de começar).
class VerifyEstimate {
  const VerifyEstimate({
    required this.files,
    required this.bytes,
    this.phoneFiles = 0,
    this.skippedDisconnected = 0,
    this.notYetConferred = 0,
  });

  final int files;
  final int bytes;

  /// Arquivos lidos pelo cabo do celular (lento).
  final int phoneFiles;

  /// Arquivos de fontes desconectadas (ficam de fora).
  final int skippedDisconnected;

  /// Arquivos ainda sem a primeira conferência (a fila normal cuida deles).
  final int notYetConferred;
}

/// Estado de uma rodada de verificação.
abstract final class RunStatus {
  static const running = 'running';
  static const paused = 'paused';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

/// Uma rodada de verificação (tela Tarefas).
class IntegrityRunView {
  const IntegrityRunView({
    required this.id,
    required this.scheduled,
    required this.status,
    required this.pausedByUser,
    required this.label,
    required this.filesTotal,
    required this.bytesTotal,
    required this.counts,
    required this.createdAt,
    this.finishedAt,
    this.message,
    this.includesPhone = false,
  });

  final int id;

  /// Feita pela verificação periódica (não pelo usuário).
  final bool scheduled;
  final String status;
  final bool pausedByUser;

  /// Ex.: "HD Backup (tudo)", "HD Backup › Fotos/2024", "12 arquivos da Biblioteca".
  final String label;
  final int filesTotal;
  final int bytesTotal;

  /// Quantos de cada [CheckResult].
  final Map<String, int> counts;
  final DateTime createdAt;
  final DateTime? finishedAt;
  final String? message;
  final bool includesPhone;

  int get filesChecked => counts.values.fold(0, (a, b) => a + b);
  int count(String result) => counts[result] ?? 0;
  bool get isOpen => status == RunStatus.running || status == RunStatus.paused;
  bool get hasProblems => count(CheckResult.possiblyCorrupt) > 0;
}

/// Um arquivo conferido numa rodada (lista de resultados).
class IntegrityCheckView {
  const IntegrityCheckView({
    required this.instanceId,
    required this.sourceId,
    required this.sourceName,
    required this.relPath,
    required this.result,
    required this.checkedAt,
    this.reason,
  });

  final int instanceId;
  final String sourceId;
  final String sourceName;
  final String relPath;
  final String result;
  final DateTime checkedAt;
  final String? reason;
}

/// Outra cópia do conteúdo que o arquivo danificado deveria ter.
class OtherCopy {
  const OtherCopy({
    required this.instanceId,
    required this.sourceId,
    required this.sourceName,
    required this.sourceKind,
    required this.relPath,
    required this.connected,
    required this.sameSource,
    required this.samePhysicalDisk,
    this.lastConfirmedAt,
    this.recentlyVerified = false,
  });

  final int instanceId;
  final String sourceId;
  final String sourceName;
  final String sourceKind;
  final String relPath;
  final bool connected;

  /// Na mesma fonte do arquivo danificado.
  final bool sameSource;

  /// No mesmo disco físico (`false` também quando não dá para saber).
  final bool samePhysicalDisk;

  /// Última vez que o conteúdo desta cópia foi lido e conferiu.
  final DateTime? lastConfirmedAt;

  /// Relida pela verificação de integridade (não só na primeira conferência).
  final bool recentlyVerified;
}

/// Arquivo possivelmente corrompido, com as outras cópias conferidas.
class IntegrityProblem {
  const IntegrityProblem({
    required this.instanceId,
    required this.sourceId,
    required this.sourceName,
    required this.relPath,
    required this.size,
    required this.detectedAt,
    required this.connected,
    required this.otherCopies,
    this.expectedContentId,
  });

  final int instanceId;
  final String sourceId;
  final String sourceName;
  final String relPath;
  final int size;
  final DateTime detectedAt;
  final bool connected;

  /// Conteúdo que o arquivo tinha quando foi conferido (`null` se o catálogo
  /// não sabe — ex.: verificação de uma versão antiga).
  final int? expectedContentId;
  final List<OtherCopy> otherCopies;

  String get name => relPath.split('/').last;

  /// Cópias de onde dá para restaurar agora.
  List<OtherCopy> get restorable => [
    for (final c in otherCopies)
      if (c.connected) c,
  ];
}

/// Situação da verificação de uma fonte (Início, Dispositivos).
class SourceIntegrity {
  const SourceIntegrity({
    required this.sourceId,
    required this.sourceName,
    required this.kind,
    required this.files,
    required this.staleFiles,
    required this.possiblyCorrupt,
    this.lastVerifiedAt,
    this.oldestConfirmedAt,
  });

  final String sourceId;
  final String sourceName;
  final String kind;

  /// Arquivos com o conteúdo conferido.
  final int files;

  /// Arquivos não conferidos há mais tempo que o intervalo configurado.
  final int staleFiles;
  final int possiblyCorrupt;

  /// Última vez que uma verificação de integridade leu algo desta fonte.
  final DateTime? lastVerifiedAt;

  /// O arquivo há mais tempo sem conferir (primeira conferência ou verificação).
  final DateTime? oldestConfirmedAt;
}

/// Verificação periódica (Configurações).
class IntegritySchedule {
  const IntegritySchedule({this.enabled = true, this.everyDays = 90});

  factory IntegritySchedule.fromJson(Object? json) {
    if (json is! Map) return const IntegritySchedule();
    return IntegritySchedule(
      enabled: json['enabled'] as bool? ?? true,
      everyDays: (json['everyDays'] as num?)?.toInt() ?? 90,
    );
  }

  /// Ligada por padrão: só discos conectados, devagar, e nunca celulares.
  final bool enabled;

  /// Confere de novo o que não é conferido há mais de N dias.
  final int everyDays;

  Map<String, Object?> toJson() => {'enabled': enabled, 'everyDays': everyDays};
}

/// Progresso da verificação em andamento.
class IntegrityProgress {
  const IntegrityProgress({
    required this.runId,
    required this.scheduled,
    required this.filesDone,
    required this.filesTotal,
    required this.bytesDone,
    required this.bytesTotal,
    this.currentName,
    this.running = true,
    this.light = false,
    this.counts = const {},
  });

  final int runId;
  final bool scheduled;
  final int filesDone;
  final int filesTotal;
  final int bytesDone;
  final int bytesTotal;
  final String? currentName;
  final bool running;

  /// Lendo devagar para não pesar no computador.
  final bool light;
  final Map<String, int> counts;
}
