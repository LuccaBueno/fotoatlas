import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart';

import '../catalog/catalog_database.dart';
import '../ops/copy_models.dart';
import '../ops/copy_planner.dart' show FreeSpaceProbe, defaultReserveBytes, fat32MaxFileSize, isFat;
import '../ops/names.dart';
import '../platform/win_fs.dart';
import '../safe_io/source_reader.dart';
import '../sources/media_types.dart';
import '../sources/sources_service.dart';
import 'zip_pull.dart';

/// Um zip do Google Takeout catalogado numa fonte.
class TakeoutZip {
  const TakeoutZip({required this.instanceId, required this.sourceId, required this.relPath, required this.size});
  final int instanceId;
  final String sourceId;
  final String relPath;
  final int size;
  String get name => relPath.split('/').last;
}

/// Extração do Google Takeout em zip (Fase 9, ADR 0025): o zip é aberto
/// **só para leitura**; fotos, vídeos e `.json` saem para uma pasta escolhida
/// pela cópia segura (prévia, diário, `.part`, CRC do zip e SHA-256
/// conferidos, publicação sem substituir). Depois, a pasta é lida como um
/// Takeout em pasta (datas e locais dos `.json` só no catálogo).
class TakeoutZips {
  TakeoutZips(this.db, this.sources, {FreeSpaceProbe? freeSpace, this.reserveBytes = defaultReserveBytes})
    : freeSpace = freeSpace ?? diskFreeBytes;

  final CatalogDatabase db;
  final SourcesService sources;
  final FreeSpaceProbe freeSpace;
  final int reserveBytes;

  /// Pasta padrão dentro do destino.
  static const defaultFolder = 'Google Fotos (Takeout)';

  /// Zips com cara de Takeout (`takeout-….zip`) catalogados em [sourceId]
  /// (ou em todas as fontes).
  Future<List<TakeoutZip>> find({String? sourceId}) async => [
    for (final r
        in await db
            .customSelect(
              "SELECT fi.id, fi.source_id, fi.rel_path, fi.size_bytes FROM file_instances fi "
              "JOIN sources s ON s.id = fi.source_id AND s.forgotten_at IS NULL AND s.kind <> 'phone' "
              "WHERE fi.ext = 'zip' AND fi.availability = 'present' AND lower(fi.name) LIKE 'takeout%' "
              "${sourceId == null ? '' : 'AND fi.source_id = ? '}ORDER BY fi.rel_path",
              variables: [if (sourceId != null) Variable.withString(sourceId)],
            )
            .get())
      TakeoutZip(
        instanceId: r.read<int>('id'),
        sourceId: r.read<String>('source_id'),
        relPath: r.read<String>('rel_path'),
        size: r.read<int>('size_bytes'),
      ),
  ];

  /// Prévia da extração (só lê o índice dos zips e o destino).
  Future<CopyPreview> preview(
    List<TakeoutZip> zips, {
    required String destSourceId,
    String destFolder = defaultFolder,
  }) async {
    final request = CopyRequest(
      contentIds: const [],
      destSourceId: destSourceId,
      destFolder: destFolder,
      template: '',
      origin: 'takeout',
      keepGroups: false,
    );
    CopyPreview blocked(String name, String why) => CopyPreview(
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
    final dest = await sources.byId(destSourceId);
    if (dest == null || dest.forgottenAt != null) return blocked('?', 'O destino escolhido não está mais cadastrado.');
    if (dest.kind == 'phone') {
      return blocked(dest.name, 'Celulares não podem ser destino: o FotoAtlas só lê do celular.');
    }
    final root = sources.accessRoot(dest);
    if (root == null) return blocked(dest.name, '"${dest.name}" está desconectado. Conecte o disco para extrair.');
    final folder = [
      for (final s in destFolder.replaceAll(r'\', '/').split('/'))
        if (s.trim().isNotEmpty && s != '.' && s != '..') sanitizeName(s),
    ].join('/');
    final fat = isFat(dest.filesystem);

    final used = {
      for (final r
          in await db
              .customSelect(
                "SELECT rel_path FROM file_instances WHERE source_id = ? AND availability != 'missing'",
                variables: [Variable.withString(destSourceId)],
              )
              .get())
        r.read<String>('rel_path').toLowerCase(),
    };
    bool taken(String rel) {
      if (used.contains(rel.toLowerCase())) return true;
      try {
        attributesOf(joinNative(root, rel));
        return true;
      } on Win32Exception {
        return false;
      }
    }

    final items = <PlannedCopy>[];
    final unavailable = <UnavailableCopy>[];
    final tooLarge = <UnavailableCopy>[];
    // Mesma entrada em duas partes do Takeout (ex.: o mesmo `.json`): uma vez só.
    final seen = <String, (int, int?)>{};
    for (final zip in zips) {
      final source = await sources.byId(zip.sourceId);
      final srcRoot = source == null ? null : sources.accessRoot(source);
      if (srcRoot == null) {
        unavailable.add(UnavailableCopy(0, zip.name, 'O disco com este zip está desconectado.'));
        continue;
      }
      final List<(String, int, int?)> entries;
      try {
        entries = await _indexInIsolate(joinNative(srcRoot, zip.relPath));
      } on Object catch (e) {
        unavailable.add(UnavailableCopy(0, zip.name, 'Não foi possível ler o zip: $e'));
        continue;
      }
      for (final (entry, size, crc) in entries) {
        final parts = entry.split('/');
        // O Takeout põe tudo em "Takeout/…": a pasta escolhida já diz de onde veio.
        final inner = parts.first.toLowerCase() == 'takeout' && parts.length > 1 ? parts.sublist(1) : parts;
        final rel = [folder, ...inner.map(sanitizeName)].where((s) => s.isNotEmpty).join('/');
        final prev = seen[rel.toLowerCase()];
        if (prev != null && prev.$1 == size && prev.$2 == crc) continue;
        if (fat && size > fat32MaxFileSize) {
          tooLarge.add(
            UnavailableCopy(0, inner.last, 'Maior que 4 GB: o disco de destino (FAT32) não aceita arquivos assim.'),
          );
          continue;
        }
        var target = rel;
        var renamed = false;
        if (taken(target)) {
          final slash = rel.lastIndexOf('/');
          final dir = slash < 0 ? '' : rel.substring(0, slash);
          final name = rel.substring(slash + 1);
          for (var n = 1; ; n++) {
            final next = dir.isEmpty ? withSuffix(name, n) : '$dir/${withSuffix(name, n)}';
            if (!taken(next)) {
              target = next;
              break;
            }
          }
          renamed = true;
        }
        seen[rel.toLowerCase()] = (size, crc);
        used.add(target.toLowerCase());
        items.add(
          PlannedCopy(
            contentId: 0,
            instanceId: zip.instanceId,
            srcSourceId: zip.sourceId,
            srcRelPath: '${zip.relPath}$zipEntrySeparator$entry',
            size: size,
            sha256: null,
            mtime: null,
            dstRelPath: target,
            originalName: inner.last == sanitizeName(inner.last) ? null : inner.last,
            renamedForConflict: renamed,
          ),
        );
      }
    }
    final folders = <String, (int, int)>{};
    for (final i in items) {
      final slash = i.dstRelPath.lastIndexOf('/');
      final dir = slash < 0 ? '' : i.dstRelPath.substring(0, slash);
      final (n, b) = folders[dir] ?? (0, 0);
      folders[dir] = (n + 1, b + i.size);
    }
    final mount = dest.lastMountPath;
    return CopyPreview(
      request: request,
      destName: dest.name,
      destDisplay: mount == null ? null : joinNative(joinNative(mount, dest.rootRelPath), folder),
      destFileSystem: dest.filesystem,
      items: items,
      alreadyThere: 0,
      alreadyThereBytes: 0,
      unavailable: unavailable,
      tooLargeForFat32: tooLarge,
      freeBytes: freeSpace(root),
      reserveBytes: reserveBytes,
      folders: [for (final e in folders.entries) PlannedFolder(e.key, e.value.$1, e.value.$2)]
        ..sort((a, b) => a.relPath.toLowerCase().compareTo(b.relPath.toLowerCase())),
    );
  }

  /// Quantos itens da prévia são fotos/vídeos e quantos são `.json`.
  static ({int media, int json, int other}) countKinds(CopyPreview p) {
    var media = 0, json = 0, other = 0;
    for (final i in p.items) {
      final name = i.dstRelPath.split('/').last;
      final dot = name.lastIndexOf('.');
      final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
      if (ext == 'json') {
        json++;
      } else if (MediaTypes.media.contains(ext)) {
        media++;
      } else {
        other++;
      }
    }
    return (media: media, json: json, other: other);
  }
}

/// Num isolate próprio; a função de fora não leva o contexto do método junto.
Future<List<(String, int, int?)>> _indexInIsolate(String zipPath) => Isolate.run(() => _index(zipPath));

/// Índice do zip (só leitura): arquivos com tamanho e CRC.
List<(String, int, int?)> _index(String zipPath) {
  final input = InputFileStream(zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    return [
      for (final f in archive.files)
        if (f.isFile && !f.name.startsWith('__MACOSX/')) (f.name, f.size, f.crc32),
    ];
  } finally {
    input.closeSync();
  }
}
