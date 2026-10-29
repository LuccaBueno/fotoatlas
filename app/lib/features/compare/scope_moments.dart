import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../library/library_strings.dart';

/// "Aniversário da Ana" ou "Aniversário da Ana (só em Pixel)".
String momentEntryLabel(MomentScopeEntry e, Map<int, MomentView> moments, Map<String, SourceView> sources) {
  final m = moments[e.momentId];
  final name = m == null ? 'Momento que não existe mais' : momentTitle(m);
  final src = e.sourceId;
  return src == null ? name : '$name (só em ${sources[src]?.name ?? 'dispositivo esquecido'})';
}

/// "2024-01-01 a 2024-12-31 · Canon EOS X".
String scopeFilterLabel(LibraryFilter f) {
  final parts = <String>[];
  final d = f.of(FilterKind.dateRange);
  if (d != null) {
    parts.add(d.values.join(' a ').replaceAll('0000-01-01 a ', 'até ').replaceAll(' a 9999-12-31', ' em diante'));
  }
  final c = f.of(FilterKind.cameras);
  if (c != null) parts.add(c.values.map((v) => cameraLabel('$v')).join(', '));
  return parts.join(' · ');
}

/// Escolher um momento (e, se quiser, só a parte dele num dispositivo).
class MomentPickerDialog extends ConsumerStatefulWidget {
  const MomentPickerDialog({super.key});

  @override
  ConsumerState<MomentPickerDialog> createState() => _MomentPickerDialogState();
}

class _MomentPickerDialogState extends ConsumerState<MomentPickerDialog> {
  String _query = '';
  String? _source;

  @override
  Widget build(BuildContext context) {
    final moments = (ref.watch(momentsProvider).value ?? const <MomentView>[]).reversed.toList();
    final sources = ref.watch(sourcesProvider).value ?? const <SourceView>[];
    final shown = moments.where((m) => _query.isEmpty || momentTitle(m).toLowerCase().contains(_query.toLowerCase()));
    return AlertDialog(
      title: const Text('Adicionar momento'),
      content: SizedBox(
        width: 480,
        height: 460,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Procurar pelo nome ou dia'),
              onChanged: (v) => setState(() => _query = v),
            ),
            DropdownButtonFormField<String?>(
              initialValue: _source,
              decoration: const InputDecoration(labelText: 'Em quais dispositivos'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Em todos')),
                for (final s in sources) DropdownMenuItem(value: s.id, child: Text('Só em ${s.name}')),
              ],
              onChanged: (v) => setState(() => _source = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: moments.isEmpty
                  ? const Center(child: Text('Ainda não há momentos (eles aparecem depois que as datas são lidas).'))
                  : ListView(
                      children: [
                        for (final m in shown)
                          ListTile(
                            key: ValueKey('pick-moment-${m.id}'),
                            leading: Icon(m.edited ? Icons.push_pin_outlined : Icons.collections_outlined),
                            title: Text(momentTitle(m)),
                            subtitle: Text(plural(m.itemCount, 'item', 'itens')),
                            onTap: () => Navigator.pop(context, MomentScopeEntry(m.id, _source)),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar'))],
    );
  }
}

/// Filtro opcional do escopo: período (datas) e câmeras.
class ScopeFilterDialog extends ConsumerStatefulWidget {
  const ScopeFilterDialog({super.key, this.initial});
  final LibraryFilter? initial;

  @override
  ConsumerState<ScopeFilterDialog> createState() => _ScopeFilterDialogState();
}

class _ScopeFilterDialogState extends ConsumerState<ScopeFilterDialog> {
  late final _from = TextEditingController(text: _date(0));
  late final _to = TextEditingController(text: _date(1));
  late final Set<String> _cameras = {...?widget.initial?.of(FilterKind.cameras)?.values.map((v) => '$v')};
  String? _error;

  String _date(int i) {
    final v = widget.initial?.of(FilterKind.dateRange)?.values.elementAtOrNull(i)?.toString();
    return v == null || v == '0000-01-01' || v == '9999-12-31' ? '' : v;
  }

  @override
  void dispose() {
    _from.dispose();
    _to.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cameras = ref.watch(libraryFacetsProvider).value?.cameras ?? const <String, int>{};
    final date = RegExp(r'^\d{4}-\d{2}-\d{2}$');
    return AlertDialog(
      title: const Text('Filtrar o escopo'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Só arquivos tirados no período (pela data da foto):'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('scope-from'),
                    controller: _from,
                    decoration: const InputDecoration(labelText: 'De (AAAA-MM-DD)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('scope-to'),
                    controller: _to,
                    decoration: const InputDecoration(labelText: 'Até (AAAA-MM-DD)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (cameras.isNotEmpty) const Text('Só destas câmeras/celulares:'),
            Wrap(
              spacing: 6,
              children: [
                for (final k in cameras.keys)
                  FilterChip(
                    label: Text(cameraLabel(k)),
                    selected: _cameras.contains(k),
                    onSelected: (v) => setState(() => v ? _cameras.add(k) : _cameras.remove(k)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Arquivos ainda sem o conteúdo conferido continuam no escopo até serem conferidos '
              '(o resultado fica "incompleto" até lá).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, LibraryFilter.empty), child: const Text('Sem filtro')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const ValueKey('scope-filter-apply'),
          onPressed: () {
            final from = _from.text.trim(), to = _to.text.trim();
            if ((from.isNotEmpty && !date.hasMatch(from)) || (to.isNotEmpty && !date.hasMatch(to))) {
              setState(() => _error = 'Use datas no formato AAAA-MM-DD.');
              return;
            }
            Navigator.pop(
              context,
              LibraryFilter([
                if (from.isNotEmpty || to.isNotEmpty)
                  FilterCondition(
                    FilterKind.dateRange,
                    values: [from.isEmpty ? '0000-01-01' : from, to.isEmpty ? '9999-12-31' : to],
                  ),
                if (_cameras.isNotEmpty) FilterCondition(FilterKind.cameras, values: _cameras.toList()),
              ]),
            );
          },
          child: const Text('Aplicar'),
        ),
      ],
    );
  }
}
