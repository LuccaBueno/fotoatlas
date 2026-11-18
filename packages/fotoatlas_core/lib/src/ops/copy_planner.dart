import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../items/media_items_service.dart';
import '../platform/win_fs.dart';
import '../safe_io/source_reader.dart';
import '../sources/sources_service.dart';
import 'copy_models.dart';
import 'names.dart';
import 'template_data.dart';

/// Espaço livre do volume de [root] (injetável nos testes de falta de espaço).
typedef FreeSpaceProbe = int? Function(String root);

/// Maior arquivo aceito pelo FAT32 (4 GiB − 1 byte).
const int fat32MaxFileSize = 0xFFFFFFFF;

/// Margem mínima que sempre fica livre no destino.
const int defaultReserveBytes = 64 * 1024 * 1024;

bool isFat(String? fileSystem) {
  final fs = (fileSystem ?? '').toUpperCase();
  return fs == 'FAT32' || fs == 'FAT' || fs == 'FAT16' || fs == 'FAT12';
}

/// Monta a prévia de uma cópia (spec §3.3, §11.1 passo 2). Só lê: catálogo e
/// atributos de arquivos no destino (para achar conflitos de nome).
class CopyPlanner {
  CopyPlanner(
    this.db,
    this.sources, {
    FreeSpaceProbe? freeSpace,
    this.reserveBytes = defaultReserveBytes,
    this.mediaItems,
  }) : freeSpace = freeSpace ?? diskFreeBytes;

  final CatalogDatabase db;
  final SourcesService sources;

  /// Itens lógicos (RAW+JPEG, Live Photo); `null` = cada arquivo sozinho.
  final MediaItemsService? mediaItems;
  final FreeSpaceProbe freeSpace;
  final int reserveBytes;

  Future<CopyPreview> plan(CopyRequest request) async {
    final dest = await sources.byId(request.destSourceId);
    if (dest == null || dest.forgottenAt != null) {
      return _blocked(request, dest?.name ?? '?', 'O destino escolhido não está mais cadastrado.');
    }
    if (dest.kind == 'phone') {
      return _blocked(request, dest.name, 'Celulares não podem ser destino: o FotoAtlas só lê do celular.');
    }
    final root = sources.accessRoot(dest);
    if (root == null) {
      return _blocked(request, dest.name, '"${dest.name}" está desconectado. Conecte o disco para copiar.');
    }
    final destFolder = _cleanFolder(request.destFolder);
    final fat = isFat(dest.filesystem);

    // Item lógico (RAW+JPEG, Live Photo): copiar um arquivo do grupo leva
    // todos, e a prévia mostra quais entraram por isso.
    final selected = request.contentIds.toSet();
    final groupOf = <int, MediaItemView>{};
    if (request.keepGroups && mediaItems != null) {
      for (final item in await mediaItems!.itemsFor(selected)) {
        for (final id in item.contentIds) {
          groupOf.putIfAbsent(id, () => item);
        }
      }
    }
    final units = <List<int>>[];
    final placed = <int>{};
    for (final id in selected) {
      if (placed.contains(id)) continue;
      final g = groupOf[id];
      final unit = g == null
          ? [id]
          : [g.primaryContentId, ...g.contentIds.where((c) => c != g.primaryContentId)].where(placed.add).toList();
      placed.add(id);
      if (unit.isNotEmpty) units.add(unit);
    }
    final allIds = [for (final u in units) ...u];

    final moments = templateUsesMoment(request.template) ? await loadMomentHeads(db) : const <int, MomentHead>{};
    final rows = await _instances(allIds, moments);
    final there = await _contentsIn(request.destSourceId, allIds);
    final byContent = <int, List<_Row>>{};
    for (final r in rows) {
      byContent.putIfAbsent(r.contentId, () => []).add(r);
    }

    final planned = <PlannedCopy>[];
    final unavailable = <UnavailableCopy>[];
    final tooLarge = <UnavailableCopy>[];
    var alreadyThere = 0;
    var alreadyBytes = 0;
    // Nomes já usados (sem caixa): do catálogo e os que esta prévia reserva.
    final used = await _usedNames(request.destSourceId);
    final prefer = request.preferSourceIds.toSet();

    /// A origem escolhida para [contentId], ou `null` (já anotado o porquê).
    _Row? pick(int contentId) {
      final candidates = byContent[contentId] ?? const <_Row>[];
      if (there.contains(contentId)) {
        alreadyThere++;
        alreadyBytes += candidates.isEmpty ? 0 : candidates.first.size;
        return null;
      }
      final usable = candidates.where((r) => r.sourceId != request.destSourceId).toList();
      if (usable.isEmpty) {
        unavailable.add(UnavailableCopy(contentId, '?', 'Nenhuma cópia catalogada (o arquivo pode ter sumido).'));
        return null;
      }
      final ready = usable.where((r) => r.availability == 'present' && _ready(r)).toList()
        ..sort((a, b) {
          final pa = prefer.contains(a.sourceId) ? 0 : 1, pb = prefer.contains(b.sourceId) ? 0 : 1;
          if (pa != pb) return pa - pb;
          // Disco antes de celular (mais rápido e com hash local).
          final ka = a.sourceKind == 'phone' ? 1 : 0, kb = b.sourceKind == 'phone' ? 1 : 0;
          if (ka != kb) return ka - kb;
          return a.instanceId - b.instanceId;
        });
      if (ready.isEmpty) {
        final r = usable.first;
        final why = usable.any((u) => u.availability == 'cloud_only')
            ? 'Está só na nuvem (não foi baixado para o computador).'
            : 'Nenhuma origem com este arquivo está conectada (ex.: "${r.sourceName}").';
        unavailable.add(UnavailableCopy(contentId, r.name, why));
        return null;
      }
      final src = ready.first;
      if (fat && src.size > fat32MaxFileSize) {
        tooLarge.add(
          UnavailableCopy(contentId, src.name, 'Maior que 4 GB: o disco de destino (FAT32) não aceita arquivos assim.'),
        );
        return null;
      }
      return src;
    }

    for (final unit in units) {
      final picked = [for (final id in unit) (id, pick(id))];
      final ready = [
        for (final (id, src) in picked)
          if (src != null) (id, src),
      ];
      if (ready.isEmpty) continue;
      // O grupo fica junto: todos na pasta da foto principal (ou do primeiro
      // que vai ser copiado) e, se um nome já existir, o mesmo sufixo em todos.
      final lead = ready.first.$2;
      final vars = lead.vars;
      final folder = [
        destFolder,
        renderFolder(request.template, vars, toConfirm: request.toConfirmFolder),
      ].where((s) => s.isNotEmpty).join('/');
      final names = [
        for (final (id, src) in ready)
          (request.fileNames[id] ?? src.name, sanitizeName(request.fileNames[id] ?? src.name)),
      ];
      String at(String name, int n) {
        final file = n == 0 ? name : withSuffix(name, n);
        return folder.isEmpty ? file : '$folder/$file';
      }

      var suffix = 0;
      final takenNow = [for (final (_, safe) in names) _taken(at(safe, 0), used, root)];
      final ask = request.conflict == ConflictPolicy.ask;
      if (!ask && takenNow.contains(true)) {
        for (suffix = 1; names.any((n) => _taken(at(n.$2, suffix), used, root)); suffix++) {}
      }
      final primaryName = unit.length > 1 ? ready.first.$2.name : null;
      for (var k = 0; k < ready.length; k++) {
        final (contentId, src) = ready[k];
        final (wanted, safeName) = names[k];
        final candidate = at(safeName, ask ? 0 : suffix);
        used.add(candidate.toLowerCase());
        planned.add(
          PlannedCopy(
            contentId: contentId,
            instanceId: src.instanceId,
            srcSourceId: src.sourceId,
            srcRelPath: src.relPath,
            size: src.size,
            sha256: src.sha256,
            mtime: src.mtime,
            dstRelPath: candidate,
            originalName: safeName == wanted ? null : wanted,
            renamedForConflict: !ask && suffix > 0,
            askConflict: ask && takenNow[k],
            lowConfidenceDate: vars.dated && lead.confidence == 'low',
            undated: templateUsesMoment(request.template)
                ? !vars.inMoment
                : !vars.dated && templateUsesDate(request.template),
            groupedWith: k == 0 ? null : primaryName,
            addedForGroup: !selected.contains(contentId),
          ),
        );
      }
    }

    final folders = <String, (int, int)>{};
    for (final i in planned) {
      final slash = i.dstRelPath.lastIndexOf('/');
      final dir = slash < 0 ? '' : i.dstRelPath.substring(0, slash);
      final (n, b) = folders[dir] ?? (0, 0);
      folders[dir] = (n + 1, b + i.size);
    }
    final folderList = [for (final e in folders.entries) PlannedFolder(e.key, e.value.$1, e.value.$2)]
      ..sort((a, b) => a.relPath.toLowerCase().compareTo(b.relPath.toLowerCase()));

    return CopyPreview(
      request: request,
      destName: dest.name,
      destDisplay: _display(dest, destFolder),
      destFileSystem: dest.filesystem,
      items: planned,
      alreadyThere: alreadyThere,
      alreadyThereBytes: alreadyBytes,
      unavailable: unavailable,
      tooLargeForFat32: tooLarge,
      freeBytes: freeSpace(root),
      reserveBytes: reserveBytes,
      folders: folderList,
    );
  }

  CopyPreview _blocked(CopyRequest request, String name, String why) => CopyPreview(
    request: request,
    destName: name,
    destDisplay: null,
    destFileSystem: null,
    items: const [],
    alreadyThere: 0,
    alreadyThereBytes: 0,
    unavailable: const [],
    tooLargeForFat32: const [],
    freeBytes: null,
    reserveBytes: reserveBytes,
    folders: const [],
    blocker: why,
  );

  String? _display(SourceRow dest, String folder) {
    final mount = dest.lastMountPath;
    if (mount == null) return null;
    return joinNative(joinNative(mount, dest.rootRelPath), folder);
  }

  bool _ready(_Row r) {
    if (sources.stateOf(r.sourceId) != SourceState.connected) return false;
    if (r.sourceKind == 'phone') return sources.deviceFor(r.sourceId)?.status == 'ok';
    return true;
  }

  /// Nome já usado no catálogo do destino, reservado por esta prévia ou
  /// presente no disco (mesmo que o destino nunca tenha sido escaneado).
  bool _taken(String relPath, Set<String> used, String root) {
    if (used.contains(relPath.toLowerCase())) return true;
    try {
      attributesOf(joinNative(root, relPath));
      return true;
    } on Win32Exception {
      return false;
    }
  }

  static String _cleanFolder(String folder) => [
    for (final s in folder.replaceAll(r'\', '/').split('/'))
      if (s.trim().isNotEmpty && s != '.' && s != '..') sanitizeName(s),
  ].join('/');

  Future<Set<String>> _usedNames(String sourceId) async {
    final rows = await db
        .customSelect(
          "SELECT rel_path FROM file_instances WHERE source_id = ? AND availability != 'missing'",
          variables: [Variable.withString(sourceId)],
          readsFrom: {db.fileInstances},
        )
        .get();
    return {for (final r in rows) r.read<String>('rel_path').toLowerCase()};
  }

  Future<Set<int>> _contentsIn(String sourceId, List<int> contentIds) async {
    final out = <int>{};
    for (final chunk in _chunks(contentIds.toSet().toList())) {
      final rows = await db
          .customSelect(
            "SELECT DISTINCT content_id FROM file_instances WHERE source_id = ? AND availability != 'missing' "
            'AND content_id IN (${List.filled(chunk.length, '?').join(',')})',
            variables: [Variable.withString(sourceId), for (final id in chunk) Variable.withInt(id)],
            readsFrom: {db.fileInstances},
          )
          .get();
      out.addAll(rows.map((r) => r.read<int>('content_id')));
    }
    return out;
  }

  Future<List<_Row>> _instances(List<int> contentIds, Map<int, MomentHead> moments) async {
    final out = <_Row>[];
    for (final chunk in _chunks(contentIds.toSet().toList())) {
      final rows = await db
          .customSelect(
            'SELECT fi.id, fi.source_id, fi.rel_path, fi.dir_rel_path, fi.name, fi.size_bytes, fi.mtime, '
            'fi.content_id, fi.availability, c.sha256, c.media_type, s.kind, s.name AS source_name, '
            '$templateColumnsSql '
            'FROM file_instances fi JOIN contents c ON c.id = fi.content_id '
            'JOIN sources s ON s.id = fi.source_id '
            'LEFT JOIN media_metadata mm ON mm.content_id = fi.content_id '
            "WHERE fi.content_id IN (${List.filled(chunk.length, '?').join(',')}) AND fi.availability != 'missing' "
            "AND fi.hash_status = 'done' AND s.forgotten_at IS NULL ORDER BY fi.id",
            variables: [for (final id in chunk) Variable.withInt(id)],
            readsFrom: {db.fileInstances, db.contents, db.sources, db.mediaMetadata},
          )
          .get();
      for (final r in rows) {
        out.add(
          _Row(
            instanceId: r.read<int>('id'),
            sourceId: r.read<String>('source_id'),
            relPath: r.read<String>('rel_path'),
            dirRelPath: r.read<String>('dir_rel_path'),
            name: r.read<String>('name'),
            size: r.read<int>('size_bytes'),
            mtime: r.readNullable<int>('mtime'),
            contentId: r.read<int>('content_id'),
            availability: r.read<String>('availability'),
            sha256: r.read<Uint8List>('sha256'),
            mediaType: r.read<String>('media_type'),
            sourceKind: r.read<String>('kind'),
            sourceName: r.read<String>('source_name'),
            confidence: r.readNullable<String>('eff_confidence'),
            vars: templateVarsFrom(
              r,
              originalDir: r.read<String>('dir_rel_path'),
              mediaType: r.read<String>('media_type'),
              sourceName: r.read<String>('source_name'),
              moments: moments,
            ),
          ),
        );
      }
    }
    return out;
  }

  static Iterable<List<int>> _chunks(List<int> ids) sync* {
    for (var i = 0; i < ids.length; i += 500) {
      yield ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
    }
  }
}

class _Row {
  const _Row({
    required this.instanceId,
    required this.sourceId,
    required this.relPath,
    required this.dirRelPath,
    required this.name,
    required this.size,
    required this.mtime,
    required this.contentId,
    required this.availability,
    required this.sha256,
    required this.mediaType,
    required this.sourceKind,
    required this.sourceName,
    this.confidence,
    required this.vars,
  });
  final int instanceId;
  final String sourceId;
  final String relPath;
  final String dirRelPath;
  final String name;
  final int size;
  final int? mtime;
  final int contentId;
  final String availability;
  final Uint8List sha256;
  final String mediaType;
  final String sourceKind;
  final String sourceName;
  final String? confidence;
  final TemplateVars vars;
}
