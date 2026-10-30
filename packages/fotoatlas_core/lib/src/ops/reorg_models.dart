import 'copy_models.dart';
import 'names.dart';

/// Tipos de operação no diário (`operations.kind`).
abstract final class OpKind {
  static const copy = 'copy';
  static const reorganize = 'reorganize_move';
  static const undo = 'undo';
}

/// Estado de um item da reorganização que foi devolvido pelo Desfazer.
const String undoneState = 'undone';

/// O que reorganizar (assistente "Reorganizar", spec §12). Só dentro de um
/// mesmo dispositivo (disco ou pasta cadastrada): os arquivos são movidos por
/// renomeação, sem copiar dados.
class ReorgRequest {
  const ReorgRequest({
    required this.sourceId,
    this.folder = '',
    this.destFolder,
    this.template = '{ano}/{ano}-{mes}-{dia} {momento}',
    this.conflict = ConflictPolicy.suffix,
    this.toConfirmFolder = undatedFolder,
    this.sidecars = true,
  });

  final String sourceId;

  /// Pasta a organizar, relativa à raiz do dispositivo (`/`), `''` = tudo.
  final String folder;

  /// Onde montar a estrutura nova (relativa à raiz); `null` = a própria [folder].
  final String? destFolder;
  final String template;
  final ConflictPolicy conflict;

  /// Pasta dos itens sem data ou fora de momentos ("Hora a confirmar").
  final String toConfirmFolder;

  /// Arquivos acompanhantes (`.xmp`, `.aae`, `.thm` com o mesmo nome) vão
  /// junto com a foto ou o vídeo.
  final bool sidecars;
}

/// Um arquivo que vai mudar de pasta (ou de nome).
class PlannedMove {
  const PlannedMove({
    required this.instanceId,
    required this.srcRelPath,
    required this.dstRelPath,
    required this.size,
    required this.mtime,
    this.contentId,
    this.originalName,
    this.renamedForConflict = false,
    this.askConflict = false,
    this.sidecarOf,
    this.lowConfidenceDate = false,
    this.toConfirm = false,
  });

  final int instanceId;
  final int? contentId;
  final String srcRelPath;
  final String dstRelPath;
  final int size;

  /// FILETIME no catálogo; conferido no disco antes de mover.
  final int? mtime;

  /// Nome na origem quando foi ajustado para o Windows aceitar.
  final String? originalName;

  /// Ganhou `_1`, `_2`… porque o nome já existia na pasta nova.
  final bool renamedForConflict;

  /// Política "perguntar": o nome já existe e o item espera a decisão.
  final bool askConflict;

  /// Caminho atual da foto/vídeo que este acompanhante segue.
  final String? sidecarOf;
  final bool lowConfidenceDate;

  /// Vai para a pasta de "Hora a confirmar" (sem data ou fora de momentos).
  final bool toConfirm;

  String get srcName => srcRelPath.split('/').last;
  String get dstName => dstRelPath.split('/').last;
}

/// Um arquivo dentro de uma pasta da prévia em árvore.
class TreeFile {
  const TreeFile(this.name, this.other, {this.conflict = false, this.toConfirm = false, this.lowConfidence = false});

  /// Nome nesta pasta.
  final String name;

  /// Na árvore "antes": para onde vai; na "depois": de onde vem (caminho completo).
  final String other;

  /// Nome ajustado por já existir na pasta (ou esperando decisão).
  final bool conflict;
  final bool toConfirm;
  final bool lowConfidence;
}

/// Uma pasta da prévia em árvore ("antes" ou "depois").
class TreeNode {
  TreeNode(this.name, this.relPath);

  final String name;

  /// Caminho relativo à raiz do dispositivo (`/`), `''` = raiz.
  final String relPath;
  final List<TreeNode> children = [];
  final List<TreeFile> files = [];

  /// Arquivos que saem (antes) ou chegam (depois) **nesta pasta** (não conta subpastas).
  int count = 0;
  int bytes = 0;
  int conflicts = 0;

  /// "Depois": a pasta ainda não existe no disco.
  bool isNew = false;

  /// "Antes": todos os arquivos catalogados desta pasta saem (ela fica vazia,
  /// mas **não é apagada**).
  bool becomesEmpty = false;

  /// Total desta pasta e das subpastas.
  int get totalCount => count + children.fold(0, (s, c) => s + c.totalCount);
  int get totalConflicts => conflicts + children.fold(0, (s, c) => s + c.totalConflicts);

  TreeNode child(String name) {
    for (final c in children) {
      if (c.name.toLowerCase() == name.toLowerCase()) return c;
    }
    final c = TreeNode(name, relPath.isEmpty ? name : '$relPath/$name');
    children.add(c);
    return c;
  }

  void sort() {
    children.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final c in children) {
      c.sort();
    }
  }

  /// Pasta por caminho (`null` se não existe na árvore).
  TreeNode? find(String relPath) {
    if (relPath == this.relPath) return this;
    for (final c in children) {
      if (relPath.toLowerCase() == c.relPath.toLowerCase() ||
          relPath.toLowerCase().startsWith('${c.relPath.toLowerCase()}/')) {
        return c.find(relPath);
      }
    }
    return null;
  }
}

/// Prévia da reorganização (regra 6: nada muda antes de confirmar).
class ReorgPreview {
  const ReorgPreview({
    required this.request,
    required this.sourceName,
    required this.sourceDisplay,
    required this.moves,
    required this.alreadyInPlace,
    required this.otherFiles,
    required this.notReady,
    required this.before,
    required this.after,
    this.blocker,
  });

  final ReorgRequest request;
  final String sourceName;

  /// Caminho no Windows da pasta organizada (`E:\Fotos`), para mostrar.
  final String? sourceDisplay;
  final List<PlannedMove> moves;

  /// Fotos e vídeos que já estão onde o modelo mandaria.
  final int alreadyInPlace;

  /// Arquivos que não são foto, vídeo nem acompanhante: ficam onde estão.
  final int otherFiles;

  /// Fotos e vídeos sem conteúdo conferido ou data lida ainda: ficam onde
  /// estão (dá para reorganizar de novo depois).
  final int notReady;
  final TreeNode before;
  final TreeNode after;

  /// Motivo para não poder começar (dispositivo desconectado, celular…).
  final String? blocker;

  bool get canStart => blocker == null && moves.isNotEmpty;
  int get totalBytes => moves.fold(0, (s, m) => s + m.size);
  int get renamedForConflict => moves.where((m) => m.renamedForConflict).length;
  int get askConflicts => moves.where((m) => m.askConflict).length;
  int get sanitized => moves.where((m) => m.originalName != null).length;
  int get toConfirm => moves.where((m) => m.toConfirm && m.sidecarOf == null).length;
  int get lowConfidence => moves.where((m) => m.lowConfidenceDate && m.sidecarOf == null).length;
  int get sidecars => moves.where((m) => m.sidecarOf != null).length;
}

/// Pasta que ficou vazia depois de uma reorganização (ou de desfazê-la).
class EmptyFolder {
  const EmptyFolder(this.relPath, {required this.empty});
  final String relPath;

  /// `false` = tem só arquivos ocultos ou de sistema (ex.: `Thumbs.db`): fica.
  final bool empty;
}

/// Decisão sobre um arquivo que espera a pessoa (tela Tarefas).
enum ReorgDecision {
  /// Desfazer: devolver mesmo tendo mudado desde a reorganização.
  moveAnyway,

  /// Nome ocupado: mover com outro nome (`_1`, `_2`…).
  rename,

  /// Deixar onde está (não mover).
  leave,

  /// Conferir de novo (ex.: depois de reconectar ou de fechar o outro programa).
  retry,
}

/// O que o Desfazer vai fazer (prévia antes de confirmar, regra 6).
class UndoPreview {
  const UndoPreview({
    required this.reorgId,
    required this.ready,
    required this.changed,
    required this.missing,
    required this.occupied,
    this.blocker,
  });

  final String reorgId;

  /// Arquivos que voltam para o lugar de antes.
  final int ready;

  /// Mudaram desde a reorganização (tamanho ou data): só voltam se você confirmar.
  final List<String> changed;

  /// Não estão mais onde a reorganização os deixou: nada a devolver.
  final List<String> missing;

  /// O lugar antigo já tem outro arquivo: esperam a sua decisão.
  final List<String> occupied;
  final String? blocker;

  int get total => ready + changed.length + missing.length + occupied.length;
  bool get canStart => blocker == null && total > 0;
}
