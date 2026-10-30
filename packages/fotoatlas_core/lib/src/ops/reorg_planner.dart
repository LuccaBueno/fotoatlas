import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../platform/win32/kernel32.dart' show fileAttributeDirectory;
import '../platform/win_fs.dart';
import '../safe_io/dest_writer.dart' show tempDirName;
import '../safe_io/source_reader.dart';
import '../sources/media_types.dart';
import '../sources/sources_service.dart';
import 'copy_models.dart';
import 'names.dart';
import 'reorg_models.dart';
import 'template_data.dart';

/// Monta a prévia da reorganização (spec §12): só lê o catálogo e atributos
/// do disco (para achar nomes ocupados e pastas que já existem).
class ReorgPlanner {
  ReorgPlanner(this.db, this.sources);

  final CatalogDatabase db;
  final SourcesService sources;

  /// Quantos arquivos cada pasta da árvore lista (as contagens são completas).
  static const filesPerNode = 200;

  Future<ReorgPreview> plan(ReorgRequest request) async {
    final source = await sources.byId(request.sourceId);
    final folder = cleanFolder(request.folder);
    final dest = request.destFolder == null ? folder : cleanFolder(request.destFolder!);
    final name = source?.name ?? '?';
    if (source == null || source.forgottenAt != null) {
      return _blocked(request, name, 'O dispositivo não está mais cadastrado.');
    }
    if (source.kind == 'phone') {
      return _blocked(request, name, 'Celulares não são reorganizados: o FotoAtlas só lê do celular.');
    }
    final root = sources.accessRoot(source);
    if (root == null) return _blocked(request, name, '"$name" está desconectado. Conecte o disco para reorganizar.');
    final display = joinNative(root, folder);
    if (await _scanning(source.id)) {
      return _blocked(request, name, 'Um escaneamento de "$name" está em andamento. Espere terminar.', display);
    }
    if (!await _scannedOnce(source.id)) {
      return _blocked(request, name, 'Escaneie "$name" antes de reorganizar.', display);
    }

    final byMoment = templateUsesMoment(request.template);
    final usesDate = templateUsesDate(request.template);
    final moments = byMoment ? await loadMomentHeads(db) : const <int, MomentHead>{};
    final rows = await _rows(source.id, folder);

    // Ocupados: tudo o que o catálogo conhece no dispositivo (inclusive o que
    // sumiu) e o que esta prévia reserva. Conservador: o caminho de quem sai
    // também conta como ocupado.
    final used = await _catalogPaths(source.id);
    bool taken(String rel) {
      if (used.contains(rel.toLowerCase())) return true;
      try {
        attributesOf(joinNative(root, rel));
        return true;
      } on Win32Exception {
        return false;
      }
    }

    String freeName(String dir, String name, int start) {
      for (var n = start; ; n++) {
        final candidate = n == 0 ? name : withSuffix(name, n);
        final rel = dir.isEmpty ? candidate : '$dir/$candidate';
        if (!taken(rel)) return rel;
      }
    }

    final principals = <_Row>[];
    final sidecars = <_Row>[];
    var otherFiles = 0;
    for (final r in rows) {
      switch (MediaTypes.mediaTypeOf(r.ext)) {
        case 'photo' || 'raw' || 'video':
          principals.add(r);
        case 'sidecar':
          sidecars.add(r);
        default:
          otherFiles++;
      }
    }

    // Acompanhantes: mesmo nome sem a extensão (IMG_0001.xmp) ou com ela
    // (IMG_0001.JPG.xmp), na mesma pasta.
    final byFull = <String, _Row>{}, byStem = <String, _Row>{};
    for (final r in principals) {
      byFull.putIfAbsent('${r.dir.toLowerCase()}/${r.name.toLowerCase()}', () => r);
      byStem.putIfAbsent('${r.dir.toLowerCase()}/${_stem(r.name).toLowerCase()}', () => r);
    }
    final sidecarsOf = <int, List<(_Row, bool)>>{};
    for (final s in sidecars) {
      final base = '${s.dir.toLowerCase()}/${_stem(s.name).toLowerCase()}';
      final full = byFull[base];
      final owner = request.sidecars ? full ?? byStem[base] : null;
      if (owner == null) {
        otherFiles++;
        continue;
      }
      (sidecarsOf[owner.instanceId] ??= []).add((s, full != null));
    }

    final moves = <PlannedMove>[];
    var inPlace = 0, notReady = 0;
    principals.sort((a, b) => a.relPath.toLowerCase().compareTo(b.relPath.toLowerCase()));
    for (final r in principals) {
      final followers = sidecarsOf[r.instanceId] ?? const [];
      if (usesDate && !r.metadataRead) {
        notReady++;
        otherFiles += followers.length;
        continue;
      }
      final vars = templateVarsFrom(
        r.raw,
        originalDir: _relativeTo(r.dir, folder),
        mediaType: r.mediaType,
        sourceName: source.name,
        moments: moments,
      );
      final dir = [
        dest,
        renderFolder(request.template, vars, toConfirm: request.toConfirmFolder),
      ].where((s) => s.isNotEmpty).join('/');
      final safe = sanitizeName(r.name);
      final wanted = dir.isEmpty ? safe : '$dir/$safe';
      if (wanted.toLowerCase() == r.relPath.toLowerCase()) {
        inPlace++;
        continue;
      }
      var target = wanted;
      var renamed = false, ask = false;
      if (taken(wanted)) {
        if (request.conflict == ConflictPolicy.ask) {
          ask = true;
        } else {
          target = freeName(dir, safe, 1);
          renamed = true;
        }
      }
      used.add(target.toLowerCase());
      final toConfirm = byMoment ? !vars.inMoment : usesDate && !vars.dated;
      moves.add(
        PlannedMove(
          instanceId: r.instanceId,
          contentId: r.contentId,
          srcRelPath: r.relPath,
          dstRelPath: target,
          size: r.size,
          mtime: r.mtime,
          originalName: safe == r.name ? null : r.name,
          renamedForConflict: renamed,
          askConflict: ask,
          lowConfidenceDate: !byMoment && vars.dated && r.confidence == 'low',
          toConfirm: toConfirm,
        ),
      );
      // Acompanhantes seguem o nome final da foto/vídeo.
      final newName = target.split('/').last;
      for (final (s, withExt) in followers) {
        final ext = s.name.substring(s.name.lastIndexOf('.'));
        final follower = sanitizeName('${withExt ? newName : _stem(newName)}$ext');
        var sTarget = dir.isEmpty ? follower : '$dir/$follower';
        var sRenamed = false;
        if (sTarget.toLowerCase() == s.relPath.toLowerCase()) continue;
        if (taken(sTarget)) {
          sTarget = freeName(dir, follower, 1);
          sRenamed = true;
        }
        used.add(sTarget.toLowerCase());
        moves.add(
          PlannedMove(
            instanceId: s.instanceId,
            contentId: s.contentId,
            srcRelPath: s.relPath,
            dstRelPath: sTarget,
            size: s.size,
            mtime: s.mtime,
            originalName: follower == s.name ? null : s.name,
            renamedForConflict: sRenamed,
            sidecarOf: r.relPath,
            toConfirm: toConfirm,
          ),
        );
      }
    }

    final (before, after) = _trees(name, rows, moves, root);
    return ReorgPreview(
      request: request,
      sourceName: name,
      sourceDisplay: display,
      moves: moves,
      alreadyInPlace: inPlace,
      otherFiles: otherFiles,
      notReady: notReady,
      before: before,
      after: after,
    );
  }

  /// Conteúdos (conferidos) de uma pasta do dispositivo, para "Copiar para
  /// outro disco…".
  Future<List<int>> contentIdsIn(String sourceId, String folder) async {
    final f = cleanFolder(folder);
    final rows = await db
        .customSelect(
          'SELECT DISTINCT content_id FROM file_instances WHERE source_id = ? AND content_id IS NOT NULL '
          "AND availability = 'present' ${f.isEmpty ? '' : 'AND (dir_rel_path = ? OR substr(dir_rel_path, 1, ?) = ?)'}",
          variables: [
            Variable.withString(sourceId),
            if (f.isNotEmpty) ...[Variable.withString(f), Variable.withInt(f.length + 1), Variable.withString('$f/')],
          ],
          readsFrom: {db.fileInstances},
        )
        .get();
    return [for (final r in rows) r.read<int>('content_id')];
  }

  (TreeNode, TreeNode) _trees(String name, List<_Row> rows, List<PlannedMove> moves, String root) {
    final before = TreeNode(name, ''), after = TreeNode(name, '');
    TreeNode nodeFor(TreeNode tree, String dir) {
      var n = tree;
      for (final s in dir.split('/')) {
        if (s.isNotEmpty) n = n.child(s);
      }
      return n;
    }

    String dirOf(String rel) {
      final i = rel.lastIndexOf('/');
      return i < 0 ? '' : rel.substring(0, i);
    }

    // Quantos arquivos ficam em cada pasta (direto), para "fica vazia".
    final remaining = <String, int>{};
    for (final r in rows) {
      remaining.update(r.dir.toLowerCase(), (n) => n + 1, ifAbsent: () => 1);
    }
    for (final m in moves) {
      final from = nodeFor(before, dirOf(m.srcRelPath));
      from
        ..count += 1
        ..bytes += m.size;
      if (from.files.length < filesPerNode) {
        from.files.add(TreeFile(m.srcName, m.dstRelPath, conflict: m.renamedForConflict || m.askConflict));
      }
      remaining.update(dirOf(m.srcRelPath).toLowerCase(), (n) => n - 1);
      final to = nodeFor(after, dirOf(m.dstRelPath));
      to
        ..count += 1
        ..bytes += m.size;
      if (m.renamedForConflict || m.askConflict) to.conflicts++;
      if (to.files.length < filesPerNode) {
        to.files.add(
          TreeFile(
            m.dstName,
            m.srcRelPath,
            conflict: m.renamedForConflict || m.askConflict,
            toConfirm: m.toConfirm,
            lowConfidence: m.lowConfidenceDate,
          ),
        );
      }
      remaining.update(dirOf(m.dstRelPath).toLowerCase(), (n) => n + 1, ifAbsent: () => 1);
    }

    void markEmpty(TreeNode n) {
      final prefix = '${n.relPath.toLowerCase()}/';
      final left = remaining.entries
          .where((e) => e.key == n.relPath.toLowerCase() || e.key.startsWith(prefix))
          .fold(0, (s, e) => s + e.value);
      n.becomesEmpty = n.relPath.isNotEmpty && left == 0;
      n.children.forEach(markEmpty);
    }

    void markNew(TreeNode n) {
      if (n.relPath.isNotEmpty) {
        try {
          n.isNew = attributesOf(joinNative(root, n.relPath)).attributes & fileAttributeDirectory == 0;
        } on Win32Exception {
          n.isNew = true;
        }
      }
      n.children.forEach(markNew);
    }

    markEmpty(before);
    markNew(after);
    before.sort();
    after.sort();
    return (before, after);
  }

  ReorgPreview _blocked(ReorgRequest request, String name, String why, [String? display]) => ReorgPreview(
    request: request,
    sourceName: name,
    sourceDisplay: display,
    moves: const [],
    alreadyInPlace: 0,
    otherFiles: 0,
    notReady: 0,
    before: TreeNode(name, ''),
    after: TreeNode(name, ''),
    blocker: why,
  );

  Future<bool> _scanning(String sourceId) async =>
      (await db
          .customSelect(
            "SELECT 1 FROM scans WHERE source_id = ? AND status = 'running' LIMIT 1",
            variables: [Variable.withString(sourceId)],
          )
          .getSingleOrNull()) !=
      null;

  Future<bool> _scannedOnce(String sourceId) async =>
      (await db
          .customSelect(
            "SELECT 1 FROM scans WHERE source_id = ? AND status = 'completed' LIMIT 1",
            variables: [Variable.withString(sourceId)],
          )
          .getSingleOrNull()) !=
      null;

  Future<Set<String>> _catalogPaths(String sourceId) async {
    final rows = await db
        .customSelect(
          'SELECT rel_path FROM file_instances WHERE source_id = ?',
          variables: [Variable.withString(sourceId)],
          readsFrom: {db.fileInstances},
        )
        .get();
    return {for (final r in rows) r.read<String>('rel_path').toLowerCase()};
  }

  Future<List<_Row>> _rows(String sourceId, String folder) async {
    final rows = await db
        .customSelect(
          'SELECT fi.id, fi.rel_path, fi.dir_rel_path, fi.name, fi.ext, fi.size_bytes, fi.mtime, fi.content_id, '
          'c.media_type, mm.content_id AS meta_content, $templateColumnsSql '
          'FROM file_instances fi LEFT JOIN contents c ON c.id = fi.content_id '
          'LEFT JOIN media_metadata mm ON mm.content_id = fi.content_id '
          "WHERE fi.source_id = ? AND fi.availability = 'present' "
          '${folder.isEmpty ? '' : 'AND (fi.dir_rel_path = ? OR substr(fi.dir_rel_path, 1, ?) = ?) '}'
          'ORDER BY fi.rel_path',
          variables: [
            Variable.withString(sourceId),
            if (folder.isNotEmpty) ...[
              Variable.withString(folder),
              Variable.withInt(folder.length + 1),
              Variable.withString('$folder/'),
            ],
          ],
          readsFrom: {db.fileInstances, db.contents, db.mediaMetadata},
        )
        .get();
    return [
      for (final r in rows)
        if (!_inTemp(r.read<String>('rel_path')))
          _Row(
            raw: r,
            instanceId: r.read<int>('id'),
            relPath: r.read<String>('rel_path'),
            dir: r.read<String>('dir_rel_path'),
            name: r.read<String>('name'),
            ext: r.read<String>('ext').toLowerCase(),
            size: r.read<int>('size_bytes'),
            mtime: r.readNullable<int>('mtime'),
            contentId: r.readNullable<int>('content_id'),
            mediaType:
                r.readNullable<String>('media_type') ?? MediaTypes.mediaTypeOf(r.read<String>('ext').toLowerCase()),
            metadataRead: r.readNullable<int>('meta_content') != null,
            confidence: r.readNullable<String>('eff_confidence'),
          ),
    ];
  }

  static bool _inTemp(String rel) => rel.toLowerCase().split('/').contains(tempDirName);

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? name : name.substring(0, dot);
  }

  static String _relativeTo(String dir, String folder) {
    if (folder.isEmpty) return dir;
    if (dir.toLowerCase() == folder.toLowerCase()) return '';
    return dir.substring(folder.length + 1);
  }
}

class _Row {
  const _Row({
    required this.raw,
    required this.instanceId,
    required this.relPath,
    required this.dir,
    required this.name,
    required this.ext,
    required this.size,
    required this.mtime,
    required this.contentId,
    required this.mediaType,
    required this.metadataRead,
    required this.confidence,
  });
  final QueryRow raw;
  final int instanceId;
  final String relPath;
  final String dir;
  final String name;
  final String ext;
  final int size;
  final int? mtime;
  final int? contentId;
  final String mediaType;
  final bool metadataRead;
  final String? confidence;
}
