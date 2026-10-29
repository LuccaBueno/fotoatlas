import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import '../../widgets/connection_badge.dart';
import 'clock_correction_dialog.dart';
import 'date_dialogs.dart';
import 'item_tile.dart';
import 'library_controller.dart';
import 'library_strings.dart';

final itemDetailProvider = FutureProvider.family<LibraryItemDetail?, int>((ref, id) {
  ref.watch(libraryChangesProvider);
  return ref.watch(libraryBackendProvider).detail(id);
});

/// Painel à direita: tudo sobre o item, com todas as localizações conhecidas.
class DetailsPanel extends ConsumerWidget {
  const DetailsPanel({super.key, required this.contentId});
  final int contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(itemDetailProvider(contentId));
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('details-panel'),
      color: theme.colorScheme.surfaceContainerLow,
      child: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('Não foi possível ler: $e')),
        data: (d) => d == null
            ? const Center(child: Text('Item não encontrado.'))
            : _Content(detail: d, onClose: () => ref.read(libraryControllerProvider.notifier).focus(null)),
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.detail, required this.onClose});
  final LibraryItemDetail detail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final item = detail.item;
    final local = item.local;
    final sources = {for (final s in ref.watch(sourcesProvider).value ?? const <SourceView>[]) s.id: s};
    final moments = ref.watch(momentsProvider).value ?? const <MomentView>[];
    final moment = moments.where((m) => m.id == item.momentId).firstOrNull;
    final backend = ref.read(libraryBackendProvider);
    final camera = item.make != null || item.model != null
        ? cameraLabel('${item.make ?? ''}\u0001${item.model ?? ''}')
        : null;

    Widget row(String label, String? value) => value == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 110, child: Text(label, style: theme.textTheme.bodySmall)),
                Expanded(child: SelectableText(value, style: theme.textTheme.bodyMedium)),
              ],
            ),
          );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(item.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            IconButton(tooltip: 'Fechar detalhes', onPressed: onClose, icon: const Icon(Icons.close)),
          ],
        ),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 4 / 3,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Thumbnail(contentId: item.contentId, mediaType: item.mediaType, size: 320),
          ),
        ),
        const SizedBox(height: 12),
        // Data e hora: a informação principal da Fase 4.
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  local == null ? 'Sem data' : formatLongDay(local),
                  style: theme.textTheme.titleSmall,
                  key: const ValueKey('detail-day'),
                ),
                if (local != null)
                  Text(
                    '${formatClock(local, subSeconds: true)}  ${formatOffset(detail.offsetMin)}',
                    style: theme.textTheme.headlineSmall,
                    key: const ValueKey('detail-time'),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      confidenceIcon(item.confidence),
                      size: 18,
                      color: item.uncertain ? theme.colorScheme.error : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${item.dateSource == DateSource.manual ? 'Hora definida por você' : confidenceLabel(item.confidence)} · '
                        '${dateSourceLabel(detail.extractedSource ?? item.dateSource)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (detail.correction != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Relógio do dispositivo corrigido (${detail.correction!.describe()}). '
                      'Original: ${detail.extracted == null ? '—' : formatWallDateTime(detail.extracted!)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (item.dateSource == DateSource.manual && detail.extracted != null)
                  Text(
                    'Original: ${formatWallDateTime(detail.extracted!)} (${dateSourceLabel(detail.extractedSource!)})',
                    style: theme.textTheme.bodySmall,
                  ),
                if (item.conflict)
                  Text(
                    'Atenção: as datas encontradas não batem (veja "Detalhes").',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                if (item.uncertain && local != null && looksLikeClockReset(local))
                  Text(
                    '1º de janeiro à meia-noite em ponto costuma ser a data de um relógio zerado '
                    '(câmera ou celular sem data configurada). Confirme ou corrija a hora.',
                    key: const ValueKey('clock-reset-note'),
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                  ),
                if (item.uncertain && !(local != null && looksLikeClockReset(local)))
                  Text(
                    'Hora incerta: entra na linha do tempo, mas fica fora dos momentos até ser confirmada ou corrigida.',
                    style: theme.textTheme.bodySmall,
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (item.uncertain && local != null)
                      FilledButton.tonal(
                        key: const ValueKey('confirm-time'),
                        onPressed: () => backend.confirmDates([item.contentId]),
                        child: const Text('A hora está certa'),
                      ),
                    OutlinedButton(
                      key: const ValueKey('edit-time'),
                      onPressed: () => showManualDateDialog(context, ref, [item.contentId], initial: local),
                      child: const Text('Corrigir a hora…'),
                    ),
                    if (item.dateSource == DateSource.manual)
                      TextButton(
                        onPressed: () => backend.clearManualDate([item.contentId]),
                        child: const Text('Voltar à hora original'),
                      ),
                    if (camera != null)
                      TextButton(
                        key: const ValueKey('fix-clock'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => ClockCorrectionDialog(
                            initialDevice: (item.make, item.model, detail.serial),
                            referenceIds: ref.read(libraryControllerProvider).selection.toList(),
                          ),
                        ),
                        child: Text('Corrigir o relógio de $camera…'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (moment != null) ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.collections_outlined),
            title: Text(momentTitle(moment)),
            subtitle: Text(plural(moment.itemCount, 'item', 'itens')),
          ),
        ],
        const SizedBox(height: 8),
        Text('Onde está', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        for (final l in detail.locations)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(sourceKindIcon(l.sourceKind)),
            title: Text(displayPath(l.sourceName, l.relPath)),
            subtitle: Text(
              [
                switch (l.availability) {
                  'missing' => 'não está mais lá',
                  'cloud_only' => 'só na nuvem',
                  'unreadable' => 'não deu para ler',
                  _ => sources[l.sourceId]?.state == SourceState.connected ? 'conectado' : 'desconectado',
                },
                if (l.hashStatus == 'done') 'conteúdo conferido',
              ].join(' · '),
            ),
          ),
        BackupStateBadge(item.backup),
        const SizedBox(height: 12),
        row('Câmera', camera),
        row('Nº de série', detail.serial),
        row('Lente', detail.lens),
        row(
          'Dimensões',
          item.width == null
              ? null
              : '${item.width} × ${item.height} (${((item.width! * item.height!) / 1e6).toStringAsFixed(1).replaceAll('.', ',')} MP)',
        ),
        row('Duração', item.durationMs == null ? null : formatVideoLength(item.durationMs!)),
        row('Tamanho', formatBytes(item.sizeBytes)),
        row(
          'Exposição',
          [
            if (detail.aperture != null) 'f/${detail.aperture!.toStringAsFixed(1).replaceAll('.', ',')}',
            if (detail.exposureS != null)
              detail.exposureS! < 1 ? '1/${(1 / detail.exposureS!).round()} s' : '${detail.exposureS} s',
            if (detail.iso != null) 'ISO ${detail.iso}',
            if (detail.focalMm != null) '${detail.focalMm!.round()} mm',
          ].join(' · ').ifEmptyNull(),
        ),
        row(
          'Localização',
          detail.lat == null
              ? null
              : '${detail.lat!.toStringAsFixed(5).replaceAll('.', ',')}; ${detail.lon!.toStringAsFixed(5).replaceAll('.', ',')}',
        ),
        if (item.metaError != null) row('Leitura', 'Não deu para ler os dados: ${item.metaError}'),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Detalhes'),
          children: [
            row('Conteúdo', item.sha256Hex),
            row('Leitor', detail.extractor),
            row('Codecs', [detail.videoCodec, detail.audioCodec].nonNulls.join(' / ').ifEmptyNull()),
            row('Software', detail.software),
            for (final c in detail.candidates)
              row(
                'Data (${dateSourceLabel(c.source)})',
                [
                  if (c.wall != null) formatWallDateTime(c.wall!),
                  if (c.wall == null && c.utcMs != null)
                    '${formatWallDateTime(DateTime.fromMillisecondsSinceEpoch(c.utcMs!, isUtc: true))} UTC',
                  if (c.offsetMin != null) formatOffset(c.offsetMin),
                  if (c.dayOnly) '(só o dia)',
                ].join(' '),
              ),
          ],
        ),
      ],
    );
  }
}

extension on String {
  String? ifEmptyNull() => isEmpty ? null : this;
}
