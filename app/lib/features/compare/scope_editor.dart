import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/connection_badge.dart';
import '../devices/add_device.dart';
import '../devices/scan_dialog.dart';
import 'compare_controller.dart';
import 'scope_moments.dart';

/// "HD Backup › Fotos/2020" (ou só o nome da fonte inteira).
String entryLabel(ScopeEntry e, Map<String, SourceView> sources) {
  final name = sources[e.sourceId]?.name ?? 'Dispositivo esquecido';
  return displayPath(name, e.relPath);
}

/// Um lado (A ou B): entradas, filtro por tipo e escopos salvos.
class ScopeEditor extends ConsumerWidget {
  const ScopeEditor({super.key, required this.side, required this.title, required this.subtitle});

  final CompareSide side;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final draft = ref.watch(compareControllerProvider.select((s) => s.side(side)));
    final controller = ref.read(compareControllerProvider.notifier);
    final sources = {for (final s in ref.watch(sourcesProvider).value ?? const <SourceView>[]) s.id: s};
    final saved = ref.watch(savedScopesProvider).value ?? const <SavedScope>[];
    final moments = {for (final m in ref.watch(momentsProvider).value ?? const <MomentView>[]) m.id: m};

    return Card(
      key: ValueKey('scope-${side.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 14, child: Text(side == CompareSide.a ? 'A' : 'B')),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(draft.savedName ?? title, style: theme.textTheme.titleMedium),
                      Text(subtitle, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Escopos salvos',
                  icon: const Icon(Icons.bookmarks_outlined),
                  onSelected: (v) => switch (v) {
                    'save' => _save(context, ref, draft),
                    'clear' => controller.clearSide(side),
                    _ => controller.loadSaved(side, saved.firstWhere((s) => 'load:${s.id}' == v)),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'save', enabled: !draft.isEmpty, child: const Text('Salvar este escopo…')),
                    PopupMenuItem(value: 'clear', enabled: !draft.isEmpty, child: const Text('Limpar')),
                    if (saved.isNotEmpty) const PopupMenuDivider(),
                    for (final s in saved) PopupMenuItem(value: 'load:${s.id}', child: Text('Usar "${s.name}"')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (draft.isEmpty)
              Text('Nenhuma pasta, dispositivo ou momento escolhido.', style: theme.textTheme.bodyMedium)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in draft.entries)
                    InputChip(
                      avatar: Icon(
                        e.relPath.isEmpty
                            ? sourceKindIcon(sources[e.sourceId]?.kind ?? 'folder')
                            : Icons.folder_outlined,
                        size: 18,
                      ),
                      label: Text(entryLabel(e, sources)),
                      onDeleted: () => controller.removeEntry(side, e),
                      deleteButtonTooltipMessage: 'Tirar do escopo',
                    ),
                  for (final m in draft.moments)
                    InputChip(
                      key: ValueKey('moment-chip-${m.momentId}'),
                      avatar: const Icon(Icons.collections_outlined, size: 18),
                      label: Text(momentEntryLabel(m, moments, sources)),
                      onDeleted: () => controller.removeMoment(side, m),
                      deleteButtonTooltipMessage: 'Tirar do escopo',
                    ),
                ],
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: ValueKey('add-${side.name}'),
              onPressed: () async {
                final entry = await showDialog<ScopeEntry>(context: context, builder: (_) => const ScopePickerDialog());
                if (entry != null) controller.addEntry(side, entry);
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar pasta ou dispositivo'),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton.icon(
                  key: ValueKey('add-moment-${side.name}'),
                  onPressed: () async {
                    final m = await showDialog<MomentScopeEntry>(
                      context: context,
                      builder: (_) => const MomentPickerDialog(),
                    );
                    if (m != null) controller.addMoment(side, m);
                  },
                  icon: const Icon(Icons.collections_outlined),
                  label: const Text('Adicionar momento'),
                ),
                TextButton.icon(
                  key: ValueKey('scope-filter-${side.name}'),
                  onPressed: () async {
                    final f = await showDialog<LibraryFilter>(
                      context: context,
                      builder: (_) => ScopeFilterDialog(initial: draft.filter),
                    );
                    if (f != null) controller.setFilter(side, f);
                  },
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text(
                    draft.filter == null ? 'Filtrar por data ou câmera' : 'Filtro: ${scopeFilterLabel(draft.filter!)}',
                  ),
                ),
                if (draft.filter != null)
                  IconButton(
                    tooltip: 'Tirar o filtro',
                    onPressed: () => controller.setFilter(side, null),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Tipos (nenhum marcado = todos):', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final t in ScopeFileType.values)
                  FilterChip(
                    label: Text(scopeTypeLabel(t)),
                    selected: draft.types.contains(t),
                    onSelected: (_) => controller.toggleType(side, t),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref, ScopeDraft draft) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        final text = TextEditingController(text: draft.savedName ?? '');
        return AlertDialog(
          title: const Text('Salvar escopo'),
          content: TextField(
            controller: text,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome', hintText: 'Ex.: Fotos do celular antigo'),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, text.text), child: const Text('Salvar')),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    final backend = ref.read(backendProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final existing = (ref.read(savedScopesProvider).value ?? const <SavedScope>[]).any(
        (s) => s.name.toLowerCase() == name.trim().toLowerCase(),
      );
      if (existing && context.mounted) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Substituir?'),
            content: Text('Já existe um escopo chamado "${name.trim()}". Substituir pelo atual?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Substituir')),
            ],
          ),
        );
        if (replace != true) return;
      }
      final saved = await backend.saveScope(name, draft.toScope(), replace: existing);
      ref.read(compareControllerProvider.notifier).markSaved(side, saved.name);
      messenger.showSnackBar(SnackBar(content: Text('Escopo "${saved.name}" salvo.')));
    } on SourceException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

/// Escolher um dispositivo inteiro ou uma pasta dele (pelo catálogo: funciona
/// mesmo com o dispositivo desconectado).
class ScopePickerDialog extends ConsumerStatefulWidget {
  const ScopePickerDialog({super.key});

  @override
  ConsumerState<ScopePickerDialog> createState() => _ScopePickerDialogState();
}

class _ScopePickerDialogState extends ConsumerState<ScopePickerDialog> {
  ScopeEntry? _selected;

  /// Cadastra um dispositivo novo, pergunta o que escanear e o deixa
  /// selecionado — sem sair da Comparar.
  Future<void> _addNew() async {
    final id = await addDevice(context, ref, addedMessage: 'Adicionado. Agora escolha o que escanear.');
    if (id == null || !mounted) return;
    setState(() => _selected = ScopeEntry(id));
    await startScanFlow(context, ref, id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = ref.watch(sourcesProvider).value ?? const <SourceView>[];
    final progress = ref.watch(scanProgressProvider).value ?? const <String, ScanProgress>{};
    return AlertDialog(
      title: const Text('Adicionar pasta ou dispositivo'),
      content: SizedBox(
        width: 520,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Não encontrou? Ela precisa ser adicionada e escaneada primeiro.',
                    key: const ValueKey('picker-hint'),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('picker-add-new'),
                  onPressed: _addNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Adicionar dispositivo…'),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: sources.isEmpty
                  ? const Center(child: Text('Nenhum dispositivo cadastrado ainda.'))
                  : ListView(
                      children: [
                        for (final s in sources)
                          _FolderNode(
                            // Remonta quando o scan termina para recarregar as pastas.
                            key: ValueKey('${s.id}-${s.lastScan?.id}'),
                            entry: ScopeEntry(s.id),
                            label: s.name,
                            icon: sourceKindIcon(s.kind),
                            subtitle: switch (progress[s.id]) {
                              final p? => 'escaneando… ${plural(p.filesSeen, 'arquivo', 'arquivos')} até agora',
                              null when s.lastScan == null => 'ainda não escaneado',
                              null => null,
                            },
                            selected: _selected,
                            onSelect: (e) => setState(() => _selected = e),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selected == null ? null : () => Navigator.pop(context, _selected),
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _FolderNode extends ConsumerStatefulWidget {
  const _FolderNode({
    super.key,
    required this.entry,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelect,
    this.subtitle,
    this.depth = 0,
  });

  final ScopeEntry entry;
  final String label;
  final IconData icon;
  final String? subtitle;
  final ScopeEntry? selected;
  final ValueChanged<ScopeEntry> onSelect;
  final int depth;

  @override
  ConsumerState<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends ConsumerState<_FolderNode> {
  bool _expanded = false;
  List<String>? _children;

  Future<void> _toggle() async {
    setState(() => _expanded = !_expanded);
    if (_expanded && _children == null) {
      final children = await ref.read(backendProvider).childFolders(widget.entry.sourceId, widget.entry.relPath);
      if (mounted) setState(() => _children = children);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _children;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          dense: widget.depth > 0,
          contentPadding: EdgeInsets.only(left: 8.0 + widget.depth * 20, right: 8),
          leading: IconButton(
            tooltip: _expanded ? 'Recolher' : 'Ver pastas',
            icon: Icon(_expanded ? Icons.expand_more : Icons.chevron_right),
            onPressed: _toggle,
          ),
          title: Row(
            children: [
              Icon(widget.icon, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.label, overflow: TextOverflow.ellipsis)),
            ],
          ),
          subtitle: widget.subtitle == null ? null : Text(widget.subtitle!),
          selected: widget.selected == widget.entry,
          onTap: () => widget.onSelect(widget.entry),
        ),
        if (_expanded && children == null) const LinearProgressIndicator(),
        if (_expanded && children != null && children.isEmpty)
          Padding(
            padding: EdgeInsets.only(left: 64.0 + widget.depth * 20, bottom: 8),
            child: Text('Sem subpastas com arquivos.', style: Theme.of(context).textTheme.bodySmall),
          ),
        if (_expanded && children != null)
          for (final c in children)
            _FolderNode(
              entry: ScopeEntry(widget.entry.sourceId, c),
              label: c.split('/').last,
              icon: Icons.folder_outlined,
              selected: widget.selected,
              onSelect: widget.onSelect,
              depth: widget.depth + 1,
            ),
      ],
    );
  }
}
