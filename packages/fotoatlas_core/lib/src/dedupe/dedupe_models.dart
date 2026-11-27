/// "Limpar repetidos" (ADR 0027): arquivos com o **mesmo conteúdo** (SHA-256)
/// no **mesmo** dispositivo. Nada sai sem a pessoa ver e confirmar; o que sai
/// vai para a Lixeira do Windows.
library;

/// Tipo da operação no diário (`operations.kind`, schema v11).
const String dedupeOpKind = 'dedupe_trash';

/// Regra da sugestão de qual cópia fica (configurável).
enum KeepRule {
  /// A da pasta mais organizada: dentro de uma pasta de data (`2024`,
  /// `2024-07`…), sem "(1)"/"Cópia" no nome e com o caminho mais curto.
  organized,

  /// A mais antiga neste disco (criada primeiro; depois a de modificação
  /// mais antiga).
  oldest,
}

/// Uma cópia de um grupo de repetidos.
class DedupeCopy {
  const DedupeCopy({
    required this.instanceId,
    required this.relPath,
    required this.sizeBytes,
    this.mtime,
    this.ctime,
    this.fullPath,
  });

  final int instanceId;

  /// Caminho relativo à raiz do dispositivo, com `/`.
  final String relPath;
  final int sizeBytes;

  /// FILETIME (100 ns desde 1601, UTC).
  final int? mtime;
  final int? ctime;

  /// Caminho completo no Windows (`E:\Fotos\IMG_1.jpg`) para mostrar e abrir;
  /// `null` com o dispositivo desconectado.
  final String? fullPath;

  String get name => relPath.substring(relPath.lastIndexOf('/') + 1);
  String get folder => relPath.contains('/') ? relPath.substring(0, relPath.lastIndexOf('/')) : '';
}

/// Arquivos com o mesmo conteúdo num dispositivo (2 ou mais cópias).
class DedupeGroup {
  const DedupeGroup({
    required this.contentId,
    required this.sizeBytes,
    required this.mediaType,
    required this.copies,
    required this.suggestedKeepId,
    required this.reason,
    this.width,
    this.height,
    this.captureLocal,
  });

  final int contentId;
  final int sizeBytes;

  /// `photo`, `raw` ou `video`.
  final String mediaType;
  final List<DedupeCopy> copies;

  /// A cópia que a regra sugere manter.
  final int suggestedKeepId;

  /// Por que essa (frase curta para a tela).
  final String reason;
  final int? width;
  final int? height;

  /// Data da captura (hora local, `AAAA-MM-DDTHH:MM:SS`), se lida.
  final String? captureLocal;

  /// Espaço que sai se só uma cópia ficar.
  int get reclaimableBytes => sizeBytes * (copies.length - 1);
}

/// Um dispositivo com repetidos, para escolher na tela.
class DedupeSourceSummary {
  const DedupeSourceSummary({
    required this.sourceId,
    required this.name,
    required this.kind,
    required this.groups,
    required this.extraFiles,
    required this.reclaimableBytes,
    this.blocker,
  });

  final String sourceId;
  final String name;
  final String kind;
  final int groups;

  /// Arquivos que sairiam se só uma cópia de cada grupo ficasse.
  final int extraFiles;
  final int reclaimableBytes;

  /// Por que não dá para limpar neste dispositivo agora (`null` = dá).
  final String? blocker;
}

/// Um grupo marcado para limpar: só [keepInstanceId] fica.
class DedupeChoice {
  const DedupeChoice(this.contentId, this.keepInstanceId);
  final int contentId;
  final int keepInstanceId;
}

/// Um arquivo que vai para a Lixeira (e a cópia que fica no lugar dele).
class DedupeRemoval {
  const DedupeRemoval({
    required this.contentId,
    required this.instanceId,
    required this.relPath,
    required this.sizeBytes,
    required this.mtime,
    required this.keepInstanceId,
    required this.keepRelPath,
  });

  final int contentId;
  final int instanceId;
  final String relPath;
  final int sizeBytes;
  final int? mtime;
  final int keepInstanceId;
  final String keepRelPath;
}

/// Prévia: exatamente o que vai para a Lixeira (nada foi tocado ainda).
class DedupePreview {
  const DedupePreview({
    required this.sourceId,
    required this.sourceName,
    required this.removals,
    required this.groups,
    this.skipped = const [],
    this.blocker,
  });

  final String sourceId;
  final String sourceName;
  final List<DedupeRemoval> removals;

  /// Grupos que entram.
  final int groups;

  /// Grupos escolhidos que não entram, com o motivo (mudaram desde a tela).
  final List<String> skipped;
  final String? blocker;

  int get files => removals.length;
  int get bytes => removals.fold(0, (s, r) => s + r.sizeBytes);
  bool get canStart => blocker == null && removals.isNotEmpty;
}
