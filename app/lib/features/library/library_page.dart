import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../widgets/backup_state.dart';
import 'clock_correction_dialog.dart';
import 'date_dialogs.dart';
import 'details_panel.dart';
import 'filter_bar.dart';
import 'item_tile.dart';
import 'library_controller.dart';
import 'library_layout.dart';
import 'library_strings.dart';
import 'selection_bar.dart';

/// Biblioteca (spec §3.2): linha do tempo única pela hora real, grade e
/// lista, filtros em chips, seleção em massa e painel de detalhes.
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  LibraryLayout? _layout;
  Object? _layoutKey;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _jump(HeaderKind kind, int key, {int? momentId}) {
    final row = _layout?.rowOf(kind, key, momentId: momentId);
    if (row == null || !_scroll.hasClients) return;
    _scroll.jumpTo(_layout!.offsetOfRow(row).clamp(0, _scroll.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(libraryControllerProvider);
    final c = ref.read(libraryControllerProvider.notifier);
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1200;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): c.selectAll,
        const SingleActivator(LogicalKeyboardKey.escape): c.clearSelection,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text('Biblioteca', style: theme.textTheme.headlineSmall),
                        Text(
                          state.loading ? 'carregando…' : plural(state.index.length, 'item', 'itens'),
                          key: const ValueKey('library-count'),
                          style: theme.textTheme.bodyMedium,
                        ),
                        SizedBox(
                          width: 260,
                          child: TextField(
                            key: const ValueKey('library-search'),
                            controller: _search,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Nome, pasta ou momento',
                              isDense: true,
                            ),
                            onSubmitted: (v) => c.setCondition(
                              v.trim().isEmpty ? null : FilterCondition(FilterKind.text, text: v.trim()),
                              FilterKind.text,
                            ),
                          ),
                        ),
                        SegmentedButton<LibraryView>(
                          key: const ValueKey('library-view'),
                          segments: const [
                            ButtonSegment(
                              value: LibraryView.timeline,
                              icon: Icon(Icons.timeline),
                              label: Text('Linha do tempo'),
                            ),
                            ButtonSegment(value: LibraryView.grid, icon: Icon(Icons.grid_view), label: Text('Grade')),
                            ButtonSegment(value: LibraryView.list, icon: Icon(Icons.view_list), label: Text('Lista')),
                          ],
                          selected: {state.view},
                          onSelectionChanged: (s) => c.setView(s.first),
                        ),
                        IconButton(
                          tooltip: state.ascending ? 'Mais antigas primeiro' : 'Mais novas primeiro',
                          onPressed: () => c.setAscending(!state.ascending),
                          icon: Icon(state.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Mais ações',
                          onSelected: (v) => switch (v) {
                            'clock' => showDialog<void>(
                              context: context,
                              builder: (_) => ClockCorrectionDialog(referenceIds: state.selection.toList()),
                            ),
                            _ => null,
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'clock', child: Text('Corrigir o relógio de um dispositivo…')),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const FilterBar(),
                    const _StatusLine(),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (wide && state.view != LibraryView.list && state.index.length > 0)
                      SizedBox(
                        width: 210,
                        child: _NavigationTree(index: state.index, onJump: _jump),
                      ),
                    if (wide && state.view != LibraryView.list && state.index.length > 0)
                      const VerticalDivider(width: 1),
                    Expanded(child: _body(context, state)),
                    if (state.focused != null) ...[
                      const VerticalDivider(width: 1),
                      SizedBox(width: 360, child: DetailsPanel(contentId: state.focused!)),
                    ],
                  ],
                ),
              ),
              if (state.selection.isNotEmpty) const SelectionBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, LibraryState state) {
    final theme = Theme.of(context);
    if (state.error != null) return Center(child: Text(state.error!));
    if (state.index.length == 0) {
      if (state.loading) return const Center(child: CircularProgressIndicator());
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            state.filter.isEmpty
                ? 'Nenhuma foto ou vídeo ainda. Adicione e escaneie um dispositivo em "Dispositivos": '
                      'as fotos aparecem aqui depois que o conteúdo é conferido.'
                : 'Nada encontrado com estes filtros.',
            key: const ValueKey('library-empty'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
        ),
      );
    }
    if (state.view == LibraryView.list) return _ListBody(state: state);
    return LayoutBuilder(
      builder: (context, box) {
        const pad = 16.0;
        final showTime = state.view == LibraryView.timeline;
        final columns = ((box.maxWidth - pad * 2 + LibraryLayout.gap) / (150 + LibraryLayout.gap)).floor().clamp(1, 40);
        final tile = (box.maxWidth - pad * 2 - LibraryLayout.gap * (columns - 1)) / columns;
        final tileHeight = tile + (showTime ? 20 : 0);
        final key = (state.index, state.view, columns, tileHeight);
        if (_layoutKey != key) {
          _layout = LibraryLayout.build(state.index, state.view, columns, tileHeight);
          _layoutKey = key;
        }
        final layout = _layout!;
        final moments = {for (final m in ref.watch(momentsProvider).value ?? const <MomentView>[]) m.id: m};
        return Scrollbar(
          controller: _scroll,
          child: ListView.builder(
            key: const ValueKey('library-gallery'),
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: pad),
            itemCount: layout.rows.length,
            itemExtentBuilder: (i, _) => i < layout.rows.length ? layout.rows[i].height : null,
            itemBuilder: (context, i) => switch (layout.rows[i]) {
              final HeaderRow h => _Header(row: h, moments: moments, state: state),
              final ItemsRow r => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var k = r.start; k < r.end; k++) ...[
                    if (k > r.start) const SizedBox(width: LibraryLayout.gap),
                    SizedBox(
                      width: tile,
                      height: tileHeight,
                      child: ItemTile(
                        contentId: state.index.ids[k],
                        size: tile,
                        selected: state.selection.contains(state.index.ids[k]),
                        focused: state.focused == state.index.ids[k],
                        showTime: showTime,
                        onTap: (ctrl, shift) => ref
                            .read(libraryControllerProvider.notifier)
                            .tap(state.index.ids[k], ctrl: ctrl, shift: shift),
                        onToggle: () => ref.read(libraryControllerProvider.notifier).toggle(state.index.ids[k]),
                      ),
                    ),
                  ],
                ],
              ),
            },
          ),
        );
      },
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.row, required this.moments, required this.state});
  final HeaderRow row;
  final Map<int, MomentView> moments;
  final LibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    switch (row.kind) {
      case HeaderKind.month:
      case HeaderKind.noDate:
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(monthLabel(row.key), style: theme.textTheme.titleLarge),
          ),
        );
      case HeaderKind.day:
        return Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(dayLabel(row.key), style: theme.textTheme.titleSmall),
          ),
        );
      case HeaderKind.moment:
        final m = moments[row.momentId];
        if (m == null) return const SizedBox.shrink();
        final sorted = moments.values.toList()..sort((a, b) => a.startUtcMs.compareTo(b.startUtcMs));
        final i = sorted.indexWhere((x) => x.id == m.id);
        final next = i >= 0 && i + 1 < sorted.length ? sorted[i + 1] : null;
        // Separar a partir do item em foco, se ele é deste momento.
        final focused = state.focused;
        final focusedIndex = focused == null ? -1 : state.index.ids.indexOf(focused);
        final split = focusedIndex >= 0 && state.index.moment[focusedIndex] == m.id ? focused : null;
        return Row(
          key: ValueKey('moment-${m.id}'),
          children: [
            Icon(
              m.edited ? Icons.push_pin_outlined : Icons.collections_outlined,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                m.name ?? 'Momento',
                style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${plural(m.itemCount, 'item', 'itens')} · '
              '${m.startLocal == null ? '' : formatClock(m.startLocal!, seconds: false)}'
              '${m.endLocal == null ? '' : '–${formatClock(m.endLocal!, seconds: false)}'}',
              style: theme.textTheme.bodySmall,
            ),
            Builder(
              builder: (context) => IconButton(
                key: ValueKey('moment-menu-${m.id}'),
                tooltip: 'Nomear, juntar ou separar',
                iconSize: 18,
                onPressed: () {
                  final box = context.findRenderObject()! as RenderBox;
                  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
                  final pos = RelativeRect.fromRect(
                    box.localToGlobal(Offset.zero, ancestor: overlay) & box.size,
                    Offset.zero & overlay.size,
                  );
                  showMomentMenu(context, ref, m, position: pos, next: next, splitAtContentId: split);
                },
                icon: const Icon(Icons.more_horiz),
              ),
            ),
          ],
        );
    }
  }
}

/// Avisos acima da galeria: leitura de metadados, itens ainda sendo
/// conferidos, ferramenta ausente e "hora a confirmar".
class _StatusLine extends ConsumerWidget {
  const _StatusLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final meta = ref.watch(metadataStatusProvider).value;
    final facets = ref.watch(libraryFacetsProvider).value;
    final backend = ref.read(libraryBackendProvider);
    final c = ref.read(libraryControllerProvider.notifier);
    final lines = <Widget>[
      if (meta != null && meta.running)
        Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lendo datas e informações das fotos… ${formatInt(meta.done)} de ${plural(meta.total, 'item', 'itens')}',
                key: const ValueKey('metadata-progress'),
              ),
            ),
            TextButton(onPressed: backend.pauseMetadata, child: const Text('Pausar')),
          ],
        )
      else if (meta != null && meta.paused)
        Row(
          children: [
            const Expanded(child: Text('Leitura das datas pausada.')),
            TextButton(onPressed: backend.startMetadata, child: const Text('Continuar')),
          ],
        ),
      if (meta?.exifToolMissing ?? false)
        Text(
          'O leitor de dados das fotos não foi encontrado: as datas vêm só do nome e da data do arquivo '
          '(veja Configurações › Datas e momentos).',
          key: const ValueKey('exiftool-missing'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
        ),
      if (facets != null && facets.pendingContent > 0)
        Text(
          '${plural(facets.pendingContent, 'arquivo ainda está', 'arquivos ainda estão')} sendo conferidos e '
          '${facets.pendingContent == 1 ? 'aparece' : 'aparecem'} aqui quando a conferência terminar.',
          style: theme.textTheme.bodySmall,
        ),
      if (facets != null && facets.toConfirm > 0)
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            key: const ValueKey('to-confirm'),
            avatar: Icon(Icons.help_outline, color: theme.colorScheme.error, size: 18),
            label: Text('${plural(facets.toConfirm, 'item', 'itens')} com hora a confirmar'),
            onPressed: () => c.setFilter(const LibraryFilter([FilterCondition(FilterKind.toConfirm)])),
          ),
        ),
    ];
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: lines),
    );
  }
}

/// Lista: uma linha por item, com data, câmera, tamanho e backup.
class _ListBody extends ConsumerWidget {
  const _ListBody({required this.state});
  final LibraryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.read(libraryItemCacheProvider);
    final c = ref.read(libraryControllerProvider.notifier);
    return ListView.builder(
      key: const ValueKey('library-list'),
      itemExtent: 64,
      itemCount: state.index.length,
      itemBuilder: (context, i) {
        final id = state.index.ids[i];
        return FutureBuilder<LibraryItem?>(
          future: cache.get(id),
          initialData: cache.peek(id),
          builder: (context, snap) {
            final item = snap.data;
            return ListTile(
              key: ValueKey('row-$id'),
              selected: state.selection.contains(id),
              leading: SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Thumbnail(contentId: id, mediaType: item?.mediaType, size: 56),
                ),
              ),
              title: Text(item?.name ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                item == null
                    ? ''
                    : [
                        item.local == null ? 'sem data' : formatWallDateTime(item.local!),
                        if (item.uncertain) 'hora incerta',
                        if (item.make != null || item.model != null)
                          cameraLabel('${item.make ?? ''}\u0001${item.model ?? ''}'),
                        formatBytes(item.sizeBytes),
                      ].join(' · '),
              ),
              trailing: item == null ? null : BackupStateBadge(item.backup),
              onTap: () {
                final keys = HardwareKeyboard.instance;
                c.tap(id, ctrl: keys.isControlPressed, shift: keys.isShiftPressed);
              },
            );
          },
        );
      },
    );
  }
}

/// Navegação ano → mês → dia → momento (pula para o cabeçalho na galeria).
class _NavigationTree extends ConsumerWidget {
  const _NavigationTree({required this.index, required this.onJump});
  final LibraryIndex index;
  final void Function(HeaderKind kind, int key, {int? momentId}) onJump;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final moments = {for (final m in ref.watch(momentsProvider).value ?? const <MomentView>[]) m.id: m};
    // ano → mês → dia → momentos (na ordem da galeria).
    final tree = <int, Map<int, Map<int, List<int>>>>{};
    var noDate = 0;
    for (var i = 0; i < index.length; i++) {
      final d = index.day[i];
      if (d == 0) {
        noDate++;
        continue;
      }
      final days = (tree[d ~/ 10000] ??= {})[d ~/ 100] ??= {};
      final list = days[d] ??= [];
      final m = index.moment[i];
      if (m != 0 && (list.isEmpty || list.last != m)) list.add(m);
    }
    return ListView(
      key: const ValueKey('library-tree'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final y in tree.entries)
          ExpansionTile(
            dense: true,
            title: Text('${y.key}', style: theme.textTheme.titleSmall),
            children: [
              for (final m in y.value.entries)
                ExpansionTile(
                  dense: true,
                  tilePadding: const EdgeInsets.only(left: 24, right: 8),
                  title: InkWell(
                    onTap: () => onJump(HeaderKind.month, m.key),
                    child: Text(formatMonthYear(m.key ~/ 100, m.key % 100)),
                  ),
                  children: [
                    for (final d in m.value.entries) ...[
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 40),
                        title: Text('Dia ${d.key % 100}'),
                        onTap: () => onJump(HeaderKind.day, d.key),
                      ),
                      for (final mo in d.value)
                        ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.only(left: 56),
                          leading: const Icon(Icons.collections_outlined, size: 16),
                          title: Text(
                            moments[mo]?.name ??
                                (moments[mo]?.startLocal == null
                                    ? 'Momento'
                                    : formatClock(moments[mo]!.startLocal!, seconds: false)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => onJump(HeaderKind.moment, d.key, momentId: mo),
                        ),
                    ],
                  ],
                ),
            ],
          ),
        if (noDate > 0)
          ListTile(dense: true, title: Text('Sem data ($noDate)'), onTap: () => onJump(HeaderKind.noDate, 0)),
      ],
    );
  }
}
