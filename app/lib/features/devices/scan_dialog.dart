import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';

/// "Escanear": a fonte inteira ou só algumas pastas. Começa o scan e devolve
/// o id dele (ou `null` se o usuário desistiu ou deu erro).
Future<int?> startScanFlow(BuildContext context, WidgetRef ref, String sourceId) async {
  final folders = await showDialog<List<String>>(
    context: context,
    builder: (_) => ScanFoldersDialog(sourceId: sourceId),
  );
  if (folders == null || !context.mounted) return null;
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await ref.read(backendProvider).startScan(sourceId, folders: folders.isEmpty ? null : folders);
  } on SourceException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
    return null;
  }
}

/// Tira as pastas que ficam dentro de outra escolhida.
List<String> _effective(Iterable<String> selected) {
  final sorted = selected.toList()..sort((a, b) => a.length.compareTo(b.length));
  final roots = <String>[];
  for (final f in sorted) {
    if (!roots.any((r) => f == r || f.startsWith('$r/'))) roots.add(f);
  }
  return roots..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// Escolher o que escanear. As pastas são lidas agora do dispositivo (só
/// leitura); o tamanho vem do último escaneamento, quando houver.
class ScanFoldersDialog extends ConsumerStatefulWidget {
  const ScanFoldersDialog({super.key, required this.sourceId});
  final String sourceId;

  @override
  ConsumerState<ScanFoldersDialog> createState() => _ScanFoldersDialogState();
}

class _ScanFoldersDialogState extends ConsumerState<ScanFoldersDialog> {
  late bool _onlySome;
  final _selected = <String>{};
  final _children = <String, List<String>>{};
  final _loading = <String>{};
  final _expanded = <String>{};
  final _errors = <String, String>{};
  final _stats = <String, FolderStats>{};

  SourceView? get _source =>
      (ref.read(sourcesProvider).value ?? const <SourceView>[]).where((s) => s.id == widget.sourceId).firstOrNull;

  @override
  void initState() {
    super.initState();
    final source = _source;
    // Só algumas pastas foram escaneadas antes: sugere as mesmas.
    _onlySome = source?.partlyScanned ?? false;
    if (_onlySome) _selected.addAll(source!.scannedFolders.map((f) => f.relPath));
    if (_onlySome) _load('');
  }

  Future<void> _load(String relPath) async {
    if (_children.containsKey(relPath) || _loading.contains(relPath)) return;
    setState(() {
      _loading.add(relPath);
      _errors.remove(relPath);
    });
    final backend = ref.read(backendProvider);
    try {
      final children = await backend.listFolders(widget.sourceId, relPath);
      final stats = await backend.folderStats(widget.sourceId, children);
      if (!mounted) return;
      setState(() {
        _children[relPath] = children;
        _stats.addAll(stats);
      });
      // Celular com um armazenamento só: já abre ele.
      if (relPath.isEmpty && children.length == 1 && (_source?.isPhone ?? false)) _toggleExpanded(children.single);
    } on Object catch (e) {
      if (mounted) setState(() => _errors[relPath] = e is SourceException ? e.message : '$e');
    } finally {
      if (mounted) setState(() => _loading.remove(relPath));
    }
  }

  void _toggleExpanded(String relPath) {
    setState(() {
      if (!_expanded.remove(relPath)) _expanded.add(relPath);
    });
    if (_expanded.contains(relPath)) _load(relPath);
  }

  bool _impliedByParent(String relPath) => _selected.any((s) => s != relPath && relPath.startsWith('$s/'));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = ref.watch(sourcesProvider.select((v) => v.value?.where((s) => s.id == widget.sourceId).firstOrNull));
    final chosen = _effective(_selected);
    return AlertDialog(
      title: Text('Escanear "${source?.name ?? 'dispositivo'}"'),
      content: SizedBox(
        width: 600,
        height: _onlySome ? 520 : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RadioGroup<bool>(
              groupValue: _onlySome,
              onChanged: (v) {
                setState(() => _onlySome = v ?? false);
                if (_onlySome) _load('');
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    key: const ValueKey('scan-whole'),
                    value: false,
                    title: const Text('Tudo'),
                    subtitle: Text(_wholeHint(source)),
                  ),
                  RadioListTile<bool>(
                    key: const ValueKey('scan-some'),
                    value: true,
                    title: const Text('Só algumas pastas'),
                    subtitle: Text(
                      source?.isPhone ?? false
                          ? 'Mais rápido pelo cabo USB. Ex.: só DCIM › Camera e WhatsApp.'
                          : 'Ex.: só a pasta de fotos de um ano.',
                    ),
                  ),
                ],
              ),
            ),
            if (_onlySome) ...[
              const Divider(),
              Expanded(child: _tree(theme, source)),
              const Divider(),
              Text(
                _selectionSummary(chosen),
                key: const ValueKey('scan-selection-summary'),
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Text('Escanear só lê: nada é gravado, movido ou apagado no dispositivo.', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('scan-start'),
          onPressed: _onlySome && chosen.isEmpty ? null : () => Navigator.pop(context, _onlySome ? chosen : <String>[]),
          child: const Text('Escanear'),
        ),
      ],
    );
  }

  static String _wholeHint(SourceView? s) {
    if (s == null || s.lastScan == null || s.fileCount == 0) return 'O dispositivo inteiro, com todas as pastas.';
    return 'O dispositivo inteiro. No último escaneamento: '
        '${plural(s.fileCount, 'arquivo', 'arquivos')}, ${formatBytes(s.fileBytes)}.';
  }

  String _selectionSummary(List<String> chosen) {
    if (chosen.isEmpty) return 'Marque as pastas que você quer escanear.';
    var files = 0, bytes = 0, unknown = 0;
    for (final c in chosen) {
      final st = _stats[c];
      if (st == null || st.files == 0) {
        unknown++;
      } else {
        files += st.files;
        bytes += st.bytes;
      }
    }
    return [
      plural(chosen.length, 'pasta escolhida', 'pastas escolhidas'),
      if (files > 0)
        'cerca de ${plural(files, 'arquivo', 'arquivos')}, ${formatBytes(bytes)} (pelo último escaneamento)',
      if (unknown > 0) '${plural(unknown, 'pasta', 'pastas')} com tamanho desconhecido (ainda não escaneada)',
    ].join(' · ');
  }

  Widget _tree(ThemeData theme, SourceView? source) {
    final rows = <Widget>[];
    void addLevel(String parent, int depth) {
      final error = _errors[parent];
      if (error != null) {
        rows.add(_message(depth, error, key: ValueKey('scan-folders-error-$parent')));
        return;
      }
      final children = _children[parent];
      if (children == null) {
        if (_loading.contains(parent)) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(left: 16.0 + depth * 24, right: 16),
              child: const LinearProgressIndicator(),
            ),
          );
        }
        return;
      }
      if (children.isEmpty) {
        rows.add(_message(depth, parent.isEmpty ? 'Nenhuma pasta encontrada.' : 'Sem subpastas.'));
        return;
      }
      for (final c in children) {
        rows.add(_row(theme, source, c, depth));
        if (_expanded.contains(c)) addLevel(c, depth + 1);
      }
    }

    addLevel('', 0);
    return ListView(children: rows);
  }

  Widget _message(int depth, String text, {Key? key}) => Padding(
    key: key,
    padding: EdgeInsets.only(left: 56.0 + depth * 24, top: 4, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _row(ThemeData theme, SourceView? source, String relPath, int depth) {
    final implied = _impliedByParent(relPath);
    final checked = implied || _selected.contains(relPath);
    final scannedAt = source?.scannedAt(relPath);
    final stats = _stats[relPath];
    final details = [
      if (scannedAt == null) 'ainda não escaneada' else 'escaneada em ${formatDateTime(scannedAt)}',
      if (stats != null && stats.files > 0)
        '${plural(stats.files, 'arquivo', 'arquivos')}, ${formatBytes(stats.bytes)}'
      else if (scannedAt == null)
        'tamanho desconhecido',
    ].join(' · ');
    return Padding(
      key: ValueKey('scan-folder-$relPath'),
      padding: EdgeInsets.only(left: depth * 24.0),
      child: Row(
        children: [
          IconButton(
            tooltip: _expanded.contains(relPath) ? 'Recolher' : 'Ver subpastas',
            icon: Icon(_expanded.contains(relPath) ? Icons.expand_more : Icons.chevron_right),
            onPressed: () => _toggleExpanded(relPath),
          ),
          Checkbox(
            value: checked,
            onChanged: implied
                ? null
                : (v) => setState(() {
                    if (v ?? false) {
                      _selected.add(relPath);
                    } else {
                      _selected.remove(relPath);
                    }
                  }),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(relPath.split('/').last, overflow: TextOverflow.ellipsis),
                Text(
                  details,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scannedAt == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
