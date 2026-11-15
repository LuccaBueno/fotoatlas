import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import '../../widgets/task_notice.dart';
import '../library/item_tile.dart';
import '../tasks/copy_wizard.dart';

/// Nome, explicação e ícone de cada nível de confiança (sempre ícone + texto).
String similarLevelLabel(SimilarLevel level) => switch (level) {
  SimilarLevel.nearIdentical => 'Quase idênticas',
  SimilarLevel.high => 'Muito parecidas',
  SimilarLevel.maybe => 'Talvez parecidas',
};

String similarLevelHint(SimilarLevel level) => switch (level) {
  SimilarLevel.nearIdentical => 'A mesma foto em outro tamanho ou qualidade (por exemplo, enviada por mensagem).',
  SimilarLevel.high => 'Quase a mesma imagem: pequeno corte, edição de brilho ou fotos em sequência.',
  SimilarLevel.maybe => 'Parecem a mesma cena, mas confira com calma: podem ser fotos diferentes.',
};

IconData similarLevelIcon(SimilarLevel level) => switch (level) {
  SimilarLevel.nearIdentical => Icons.filter_none,
  SimilarLevel.high => Icons.burst_mode_outlined,
  SimilarLevel.maybe => Icons.help_outline,
};

Color _levelColor(BuildContext context, SimilarLevel level) {
  final colors = StatusColors.of(context);
  return switch (level) {
    SimilarLevel.nearIdentical => colors.verified,
    SimilarLevel.high => colors.independent,
    SimilarLevel.maybe => colors.attention,
  };
}

/// Nível mínimo escolhido no filtro.
class SimilarMinLevel extends Notifier<SimilarLevel> {
  @override
  SimilarLevel build() => SimilarLevel.high;

  void select(SimilarLevel level) => state = level;
}

final similarMinLevelProvider = NotifierProvider<SimilarMinLevel, SimilarLevel>(SimilarMinLevel.new);

/// Grupos sugeridos (recalculados quando algo muda).
final similarGroupsProvider = FutureProvider<List<SimilarGroup>>((ref) {
  ref.watch(similarChangesProvider);
  return ref.watch(similarBackendProvider).groups(ref.watch(similarMinLevelProvider));
});

final similarOverviewProvider = FutureProvider<SimilarOverview>((ref) {
  ref.watch(similarChangesProvider);
  return ref.watch(similarBackendProvider).overview();
});

/// Fotos parecidas: só sugestões. Nada é apagado, movido ou alterado.
class SimilarPage extends ConsumerWidget {
  const SimilarPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(similarGroupsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos parecidas'),
        actions: [
          TextButton.icon(
            key: const ValueKey('similar-restore'),
            onPressed: () => _restoreDismissed(context, ref),
            icon: const Icon(Icons.restore),
            label: const Text('Mostrar de novo as descartadas'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Fotos diferentes que parecem a mesma: a mesma foto em outro tamanho ou qualidade, um pequeno corte, '
            'fotos em sequência. São só sugestões — o FotoAtlas não apaga, não move e não altera nenhuma foto. '
            'Cópias idênticas (o mesmo conteúdo) já aparecem uma vez só na Biblioteca.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          const _AnalysisCard(),
          const SizedBox(height: 16),
          const _LevelFilter(),
          const SizedBox(height: 16),
          ...groups.when(
            loading: () => [
              const Center(
                child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
              ),
            ],
            error: (e, _) => [Text('Não foi possível montar as sugestões: $e')],
            data: (list) => list.isEmpty
                ? [
                    Padding(
                      key: const ValueKey('similar-empty'),
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nenhuma sugestão por enquanto. Fotos novas entram aqui depois de conferidas e analisadas.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ]
                : [
                    Text(
                      plural(list.length, 'grupo sugerido', 'grupos sugeridos'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final g in list) _GroupCard(key: ValueKey('similar-group-${g.contentIds.first}'), group: g),
                  ],
          ),
        ],
      ),
    );
  }

  Future<void> _restoreDismissed(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final n = await ref.read(similarBackendProvider).restoreAllDismissed();
    messenger.showSnackBar(
      SnackBar(
        key: const ValueKey('similar-restored'),
        content: Text(
          n == 0
              ? 'Não há sugestões descartadas.'
              : 'As sugestões descartadas voltaram (${plural(n, 'par', 'pares')}). Só o catálogo mudou.',
        ),
      ),
    );
  }
}

class _AnalysisCard extends ConsumerWidget {
  const _AnalysisCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(similarStatusProvider).value ?? const SimilarStatus();
    final overview = ref.watch(similarOverviewProvider).value;
    final theme = Theme.of(context);
    final String text;
    if (status.running) {
      text = 'Analisando as fotos: ${formatInt(status.done)} de ${formatInt(status.total)}.';
    } else if (status.waiting) {
      text = 'Esperando outras tarefas terminarem (escaneamento, conferência, cópia…). A análise continua sozinha.';
    } else if (status.paused) {
      text = 'Análise pausada.';
    } else if (overview != null) {
      text = overview.photos == 0
          ? 'Nenhuma foto conferida ainda.'
          : '${formatInt(overview.analyzed)} de ${plural(overview.photos, 'foto analisada', 'fotos analisadas')}. '
                'Fotos só no celular são analisadas quando a miniatura já foi vista na Biblioteca.';
    } else {
      text = '';
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.image_search, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(key: const ValueKey('similar-status'), text),
                  if (status.running && status.total > 0) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: status.done / status.total),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (status.running)
              OutlinedButton.icon(
                key: const ValueKey('similar-pause'),
                onPressed: () => ref.read(similarBackendProvider).pause(),
                icon: const Icon(Icons.pause),
                label: const Text('Pausar'),
              )
            else
              OutlinedButton.icon(
                key: const ValueKey('similar-start'),
                onPressed: () => ref.read(similarBackendProvider).start(),
                icon: const Icon(Icons.play_arrow),
                label: Text(status.paused ? 'Continuar' : 'Analisar agora'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LevelFilter extends ConsumerWidget {
  const _LevelFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final level = ref.watch(similarMinLevelProvider);
    return Wrap(
      spacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Mostrar:'),
        SegmentedButton<SimilarLevel>(
          key: const ValueKey('similar-level'),
          segments: const [
            ButtonSegment(
              value: SimilarLevel.nearIdentical,
              icon: Icon(Icons.filter_none),
              label: Text('Só quase idênticas'),
            ),
            ButtonSegment(
              value: SimilarLevel.high,
              icon: Icon(Icons.burst_mode_outlined),
              label: Text('Até muito parecidas'),
            ),
            ButtonSegment(
              value: SimilarLevel.maybe,
              icon: Icon(Icons.help_outline),
              label: Text('Todas, até "talvez"'),
            ),
          ],
          selected: {level},
          onSelectionChanged: (s) => ref.read(similarMinLevelProvider.notifier).select(s.single),
        ),
      ],
    );
  }
}

/// Selo do nível: ícone + texto + cor, com a explicação na dica.
class SimilarLevelBadge extends StatelessWidget {
  const SimilarLevelBadge(this.level, {super.key});
  final SimilarLevel level;

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(context, level);
    return Tooltip(
      message: similarLevelHint(level),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(similarLevelIcon(level), size: 18, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              similarLevelLabel(level),
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends ConsumerWidget {
  const _GroupCard({super.key, required this.group});
  final SimilarGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = group.contentIds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SimilarLevelBadge(group.level),
                const SizedBox(width: 12),
                Text(plural(ids.length, 'foto', 'fotos')),
                const Spacer(),
                TextButton.icon(
                  key: ValueKey('similar-dismiss-${ids.first}'),
                  onPressed: () => dismissGroup(context, ref, ids),
                  icon: const Icon(Icons.close),
                  label: const Text('Não são parecidas'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  key: ValueKey('similar-compare-${ids.first}'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => SimilarCompareDialog(group: group),
                  ),
                  icon: const Icon(Icons.compare),
                  label: const Text('Comparar lado a lado'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: ids.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                    dimension: 120,
                    child: Thumbnail(contentId: ids[i], mediaType: 'photo', size: 120),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Não são parecidas": só catálogo, com Desfazer.
Future<void> dismissGroup(BuildContext context, WidgetRef ref, List<int> ids) async {
  final messenger = ScaffoldMessenger.of(context);
  final backend = ref.read(similarBackendProvider);
  final pairs = await backend.dismiss(ids);
  messenger.showSnackBar(
    SnackBar(
      key: const ValueKey('similar-dismissed'),
      content: const Text('Essas fotos não serão mais sugeridas juntas. Nenhuma foto foi alterada.'),
      action: SnackBarAction(label: 'Desfazer', onPressed: () => backend.undoDismiss(pairs)),
      duration: const Duration(seconds: 10),
      // Com ação, o SnackBar ficaria fixo por padrão.
      persist: false,
    ),
  );
}

/// Comparação lado a lado: miniatura grande, tamanho, data, câmera, onde está
/// cada cópia e situação de backup. Ações só no catálogo ou pela cópia segura.
class SimilarCompareDialog extends ConsumerStatefulWidget {
  const SimilarCompareDialog({super.key, required this.group});
  final SimilarGroup group;

  @override
  ConsumerState<SimilarCompareDialog> createState() => _SimilarCompareDialogState();
}

class _SimilarCompareDialogState extends ConsumerState<SimilarCompareDialog> {
  late List<int> _ids = [...widget.group.contentIds];
  final Set<int> _selected = {};
  late final Future<List<LibraryItemDetail?>> _details = Future.wait([
    for (final id in widget.group.contentIds) ref.read(libraryBackendProvider).detail(id),
  ]);

  /// Nível de cada foto em relação à primeira (a referência).
  SimilarLevel? _levelToReference(int id) {
    final ref0 = _ids.first;
    if (id == ref0) return null;
    for (final p in widget.group.pairs) {
      if ((p.a == ref0 && p.b == id) || (p.b == ref0 && p.a == id)) return p.level;
    }
    return null;
  }

  Future<void> _removeFromGroup(int id) async {
    final others = [
      for (final o in _ids)
        if (o != id) o,
    ];
    final backend = ref.read(similarBackendProvider);
    final pairs = await backend.dismissFrom(id, others);
    if (!mounted) return;
    setState(() {
      _ids = others;
      _selected.remove(id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: const ValueKey('similar-removed'),
        content: const Text('A foto saiu do grupo. Nenhuma foto foi alterada.'),
        action: SnackBarAction(label: 'Desfazer', onPressed: () => backend.undoDismiss(pairs)),
        duration: const Duration(seconds: 10),
        persist: false,
      ),
    );
    if (_ids.length < 2 && mounted) Navigator.pop(context);
  }

  Future<void> _copySelected() async {
    final ids = [..._selected];
    final id = await showCopyWizard(context, contents: () async => ids, origin: 'similar');
    if (id == null || !mounted) return;
    showTaskStartedNotice(
      ScaffoldMessenger.of(context),
      ref,
      'Cópia iniciada. Acompanhe em Tarefas.',
      key: const ValueKey('copy-started'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      key: const ValueKey('similar-compare'),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: size.width - 48,
        height: size.height - 48,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Comparar lado a lado', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 16),
                  SimilarLevelBadge(widget.group.level),
                  const Spacer(),
                  IconButton(tooltip: 'Fechar', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Marque as fotos que quiser copiar para outro lugar. Nada aqui apaga, move ou altera uma foto.',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<LibraryItemDetail?>>(
                  future: _details,
                  builder: (context, snap) {
                    final details = snap.data;
                    if (details == null) return const Center(child: CircularProgressIndicator());
                    final byId = {
                      for (var i = 0; i < widget.group.contentIds.length; i++) widget.group.contentIds[i]: details[i],
                    };
                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _ids.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (_, i) => _ComparedPhoto(
                        key: ValueKey('similar-photo-${_ids[i]}'),
                        contentId: _ids[i],
                        detail: byId[_ids[i]],
                        reference: i == 0,
                        level: _levelToReference(_ids[i]),
                        selected: _selected.contains(_ids[i]),
                        onSelected: (v) => setState(() => v ? _selected.add(_ids[i]) : _selected.remove(_ids[i])),
                        onRemove: () => _removeFromGroup(_ids[i]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton.icon(
                    key: const ValueKey('similar-compare-dismiss'),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await dismissGroup(context, ref, _ids);
                      navigator.pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Não são parecidas'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    key: const ValueKey('similar-copy'),
                    onPressed: _selected.isEmpty ? null : _copySelected,
                    icon: const Icon(Icons.copy_all),
                    label: Text(
                      _selected.isEmpty
                          ? 'Copiar para…'
                          : 'Copiar ${plural(_selected.length, 'foto marcada', 'fotos marcadas')} para…',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparedPhoto extends StatelessWidget {
  const _ComparedPhoto({
    super.key,
    required this.contentId,
    required this.detail,
    required this.reference,
    required this.level,
    required this.selected,
    required this.onSelected,
    required this.onRemove,
  });

  final int contentId;
  final LibraryItemDetail? detail;
  final bool reference;
  final SimilarLevel? level;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = detail?.item;
    final lines = <(String, String)>[
      if (item != null) ...[
        ('Nome', item.name),
        ('Resolução', item.width != null && item.height != null ? '${item.width} × ${item.height} px' : 'desconhecida'),
        ('Tamanho', formatBytes(item.sizeBytes)),
        ('Data', item.local == null ? 'sem data' : formatWallDateTime(item.local!)),
        if (item.make != null || item.model != null) ('Câmera', [item.make, item.model].whereType<String>().join(' ')),
        ('Cópias', plural(item.copies, 'cópia', 'cópias')),
      ],
    ];
    return SizedBox(
      width: 300,
      child: Card(
        color: selected ? theme.colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: Thumbnail(contentId: contentId, mediaType: 'photo', size: 276),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    key: ValueKey('similar-select-$contentId'),
                    value: selected,
                    onChanged: (v) => onSelected(v ?? false),
                  ),
                  const Text('Marcar'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: reference
                          ? Text('Referência', style: theme.textTheme.labelMedium)
                          : level == null
                          ? const SizedBox.shrink()
                          : SimilarLevelBadge(level!),
                    ),
                  ),
                ],
              ),
              if (item != null) BackupStateBadge(item.backup),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final (k, v) in lines)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: '$k: ', style: theme.textTheme.bodySmall),
                              TextSpan(text: v),
                            ],
                          ),
                        ),
                      ),
                    if (detail != null && detail!.locations.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('Onde está', style: theme.textTheme.labelLarge),
                      for (final l in detail!.locations)
                        Text(displayPath(l.sourceName, l.relPath), style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: ValueKey('similar-remove-$contentId'),
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Tirar do grupo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
