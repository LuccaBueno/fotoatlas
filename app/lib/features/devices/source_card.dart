import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import '../../widgets/connection_badge.dart';

/// Cartão de uma fonte. Desconectada aparece esmaecida, mas com os dados do
/// último escaneamento (regra 9).
class SourceCard extends ConsumerWidget {
  const SourceCard({super.key, required this.source, this.progress});

  final SourceView source;
  final ScanProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = source;
    final scanning = progress != null;
    final lastScan = s.lastScan;
    final resumable =
        !scanning && lastScan != null && (lastScan.status == 'paused' || lastScan.status == 'interrupted');

    return Opacity(
      opacity: s.isConnected || s.state == SourceState.ambiguous ? 1 : 0.6,
      child: Card(
        key: ValueKey('source-${s.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(sourceKindIcon(s.kind), size: 32, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Wrap(
                          spacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConnectionBadge(s.state),
                            if (s.displayPath != null) Text(s.displayPath!, style: theme.textTheme.bodySmall),
                            if (s.isPhone)
                              Text(
                                [
                                  s.devicePlatform == 'iphone' ? 'iPhone' : sourceKindLabel(s.kind),
                                  if (s.deviceSimulated) 'simulado',
                                  if (s.deviceStatus != null && s.deviceStatus != 'ok')
                                    deviceStatusLabel(s.deviceStatus!),
                                ].join(' · '),
                                style: theme.textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _Actions(source: s, progress: progress, resumable: resumable),
                ],
              ),
              const SizedBox(height: 12),
              Text(_summary(s), style: theme.textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(_details(s, scanning), style: theme.textTheme.bodySmall),
              _CoverageLine(sourceId: s.id),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: HashProgressBar(sourceId: s.id),
              ),
              if (scanning) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress!.dirsDone + progress!.dirsPending == 0
                      ? null
                      : progress!.dirsDone / (progress!.dirsDone + progress!.dirsPending),
                ),
                const SizedBox(height: 4),
                Text(
                  'Escaneando… ${plural(progress!.filesSeen, 'arquivo encontrado', 'arquivos encontrados')} '
                  '(${formatBytes(progress!.bytesSeen)})',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              if (s.state == SourceState.ambiguous) ...[const SizedBox(height: 12), _AmbiguousHelp(source: s)],
              if (s.isPhone && s.isConnected && !s.isReady) ...[
                const SizedBox(height: 12),
                _Notice(
                  key: ValueKey('phone-locked-${s.id}'),
                  icon: Icons.lock_outline,
                  text: s.deviceStatus == 'locked' ? lockedMessage : unauthorizedMessage,
                ),
              ],
              if (s.isPhone && s.devicePlatform == 'iphone') ...[
                const SizedBox(height: 12),
                _Notice(key: ValueKey('iphone-originals-${s.id}'), icon: Icons.info_outline, text: iphoneOriginalsHint),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _summary(SourceView s) {
    if (s.lastScan == null) return 'Ainda não escaneado.';
    final parts = [
      plural(s.mediaCount, 'foto ou vídeo', 'fotos e vídeos'),
      plural(s.fileCount, 'arquivo', 'arquivos'),
      formatBytes(s.fileBytes),
    ];
    return parts.join(' · ');
  }

  static String _details(SourceView s, bool scanning) {
    final parts = <String>[];
    final scan = s.lastScan;
    if (!scanning && scan != null) {
      final when = scan.finishedAt ?? scan.startedAt;
      parts.add(switch (scan.status) {
        'completed' when scan.coverage == 'partial' =>
          'Escaneado em ${formatEpochMs(when)}, mas ${plural(scan.errorCount, 'pasta não pôde ser lida', 'pastas não puderam ser lidas')}',
        'completed' => 'Escaneado em ${formatEpochMs(when)}',
        'paused' => 'Escaneamento pausado — clique em "Retomar" para continuar',
        'interrupted' => 'Escaneamento interrompido — clique em "Retomar" para continuar de onde parou',
        'cancelled' => 'Último escaneamento cancelado em ${formatEpochMs(when)}',
        _ => 'Último escaneamento: ${scan.status}',
      });
    }
    if (s.state == SourceState.disconnected && s.lastConnectedAt != null) {
      parts.add('visto pela última vez em ${formatDateTime(s.lastConnectedAt!)}');
    }
    if (s.isConnected && s.totalBytes != null) {
      parts.add('${formatBytes(s.freeBytes)} livres de ${formatBytes(s.totalBytes)}');
    }
    if (s.missingCount > 0) {
      parts.add('${plural(s.missingCount, 'arquivo sumiu', 'arquivos sumiram')} desde escaneamentos anteriores');
    }
    return parts.join(' · ');
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.source, required this.progress, required this.resumable});

  final SourceView source;
  final ScanProgress? progress;
  final bool resumable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backend = ref.read(backendProvider);
    final messenger = ScaffoldMessenger.of(context);
    Future<void> guard(Future<void> Function() action) async {
      try {
        await action();
      } on SourceException catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    }

    final running = progress;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (running != null) ...[
          OutlinedButton.icon(
            onPressed: () => guard(() => backend.pauseScan(running.scanId)),
            icon: const Icon(Icons.pause),
            label: const Text('Pausar'),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: () => guard(() => backend.cancelScan(running.scanId)), child: const Text('Cancelar')),
        ] else
          FilledButton.tonalIcon(
            onPressed: source.isReady ? () => guard(() => backend.startScan(source.id)) : null,
            icon: Icon(resumable ? Icons.play_arrow : Icons.search),
            label: Text(resumable ? 'Retomar' : 'Escanear'),
          ),
        PopupMenuButton<String>(
          tooltip: 'Mais opções',
          onSelected: (value) => switch (value) {
            'rename' => _rename(context, ref),
            'forget' => _forget(context, ref),
            _ => null,
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Renomear')),
            PopupMenuItem(value: 'forget', child: Text('Esquecer este dispositivo')),
          ],
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: source.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Renomear'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nome'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Salvar')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) await ref.read(backendProvider).rename(source.id, name);
  }

  Future<void> _forget(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Esquecer "${source.name}"?'),
        content: const Text(
          'O dispositivo sai da lista do FotoAtlas. Nenhum arquivo é apagado ou alterado — '
          'só as informações guardadas pelo FotoAtlas deixam de aparecer.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Esquecer')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(backendProvider).forget(source.id);
  }
}

/// Aviso em destaque dentro do cartão (celular bloqueado, iPhone…).
class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}

class _AmbiguousHelp extends ConsumerWidget {
  const _AmbiguousHelp({required this.source});
  final SourceView source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Há mais de uma unidade parecida com este dispositivo. Qual delas é ele?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final v in source.candidates)
              OutlinedButton(
                onPressed: () => ref.read(backendProvider).confirmVolume(source.id, v.guidPath),
                child: Text('${v.label?.isNotEmpty == true ? v.label : 'Sem nome'} (${v.displayMount ?? 'sem letra'})'),
              ),
          ],
        ),
      ],
    );
  }
}

/// Situação de backup das fotos e vídeos desta fonte + espaço em repetidos.
class _CoverageLine extends ConsumerWidget {
  const _CoverageLine({required this.sourceId});
  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(coverageProvider.select((r) => r.value?.perSource[sourceId]));
    if (c == null || c.counts.totalFiles == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final state in BackupState.values)
            if (c.counts.filesIn(state) > 0) BackupStateBadge(state, count: c.counts.filesIn(state)),
          if (c.counts.verifiedUncertainDisk > 0)
            Tooltip(
              message: verifiedHint(c.counts.filesIn(BackupState.verified), c.counts.verifiedUncertainDisk),
              child: Text(
                uncertainDiskShort(c.counts.filesIn(BackupState.verified), c.counts.verifiedUncertainDisk),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (c.cloudOnly > 0)
            Text(
              plural(c.cloudOnly, 'arquivo só na nuvem', 'arquivos só na nuvem'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (c.duplicateFiles > 0)
            Text(
              '${plural(c.duplicateFiles, 'arquivo repetido', 'arquivos repetidos')} (${formatBytes(c.duplicateBytes)})',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
