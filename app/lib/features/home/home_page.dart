import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import '../../widgets/connection_badge.dart';

/// Início: as respostas às perguntas "o que eu tenho e onde está?" e "o que já
/// tem backup e o que ainda não tem?", alertas e atalhos.
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    final progress = ref.watch(scanProgressProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: sources.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Não foi possível carregar: $e')),
        data: (list) => list.isEmpty
            ? _Welcome(onAdd: () => ref.read(navigationIndexProvider.notifier).select(devicesDestination))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _Overview(sources: list),
                  const SizedBox(height: 16),
                  ..._alerts(context, list, progress),
                  const SizedBox(height: 16),
                  const _CoveragePanel(),
                  const SizedBox(height: 16),
                  _PerSource(sources: list),
                ],
              ),
      ),
    );
  }

  List<Widget> _alerts(BuildContext context, List<SourceView> list, Map<String, ScanProgress> progress) {
    final colors = StatusColors.of(context);
    final alerts = <Widget>[];
    for (final s in list) {
      final p = progress[s.id];
      if (p != null) {
        alerts.add(
          _Alert(
            icon: Icons.search,
            color: Theme.of(context).colorScheme.primary,
            text:
                'Escaneando "${s.name}": ${plural(p.filesSeen, 'arquivo encontrado', 'arquivos encontrados')} até agora.',
          ),
        );
      } else if (s.state == SourceState.ambiguous) {
        alerts.add(
          _Alert(
            icon: Icons.help_outline,
            color: colors.attention,
            text: 'Confirme qual unidade é "${s.name}" na tela Dispositivos.',
          ),
        );
      } else if (s.lastScan == null && s.isConnected) {
        alerts.add(
          _Alert(
            icon: Icons.info_outline,
            color: colors.attention,
            text: '"${s.name}" ainda não foi escaneado. Escaneie para saber o que tem nele.',
          ),
        );
      } else if (s.lastScan?.status == 'interrupted' || s.lastScan?.status == 'paused') {
        alerts.add(
          _Alert(
            icon: Icons.pause_circle_outline,
            color: colors.attention,
            text: 'O escaneamento de "${s.name}" ficou pela metade. Você pode retomá-lo em Dispositivos.',
          ),
        );
      } else if (s.state == SourceState.disconnected) {
        alerts.add(
          _Alert(
            icon: Icons.link_off,
            color: colors.disconnected,
            text:
                '"${s.name}" está desconectado. Mostrando o que ele tinha'
                '${s.lastConnectedAt == null ? '' : ' em ${formatDateTime(s.lastConnectedAt!)}'}.',
          ),
        );
      }
    }
    return alerts;
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.sources});
  final List<SourceView> sources;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = sources.fold<int>(0, (sum, s) => sum + s.mediaCount);
    final bytes = sources.fold<int>(0, (sum, s) => sum + s.fileBytes);
    final connected = sources.where((s) => s.isConnected).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que você tem e onde está', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '${plural(media, 'foto ou vídeo', 'fotos e vídeos')} em ${plural(sources.length, 'dispositivo', 'dispositivos')}',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${formatBytes(bytes)} catalogados · ${plural(connected, 'dispositivo conectado', 'dispositivos conectados')} agora',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PerSource extends ConsumerWidget {
  const _PerSource({required this.sources});
  final List<SourceView> sources;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coverage = ref.watch(coverageProvider).value;
    return Card(
      child: Column(
        children: [
          for (final s in sources)
            ListTile(
              leading: Icon(sourceKindIcon(s.kind)),
              title: Text(s.name),
              subtitle: Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  ConnectionBadge(s.state),
                  if (coverage?.perSource[s.id] case final c? when c.counts.filesIn(BackupState.single) > 0)
                    BackupStateBadge(BackupState.single, count: c.counts.filesIn(BackupState.single)),
                ],
              ),
              trailing: Text(
                s.lastScan == null ? 'não escaneado' : plural(s.mediaCount, 'foto ou vídeo', 'fotos e vídeos'),
              ),
            ),
        ],
      ),
    );
  }
}

/// "O que já tem backup e o que ainda não tem?" (spec §3.2, Início).
class _CoveragePanel extends ConsumerWidget {
  const _CoveragePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final report = ref.watch(coverageProvider).value;
    final hash = ref.watch(hashStatusProvider).value;
    final single = report?.overall.filesIn(BackupState.single) ?? 0;
    final pending = report?.pendingFiles ?? 0;
    final headline = report == null
        ? 'Calculando…'
        : report.overall.totalFiles == 0
        ? 'Escaneie um dispositivo para saber o que tem backup.'
        : single == 0 && pending == 0
        ? 'Todas as fotos e vídeos conhecidos têm pelo menos uma cópia idêntica.'
        : single > 0
        ? '${plural(single, 'foto ou vídeo existe', 'fotos e vídeos existem')} em um lugar só'
              ' (${formatBytes(report.overall.bytesIn(BackupState.single))}).'
        : 'Ainda conferindo o conteúdo dos arquivos.';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('O que já tem backup e o que ainda não tem', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(headline, style: theme.textTheme.titleLarge),
            if (report != null && report.overall.totalFiles > 0) ...[
              const SizedBox(height: 12),
              for (final state in BackupState.values)
                if (report.overall.filesIn(state) > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(backupStateIcon(state), color: backupStateColor(context, state)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${backupStateLabel(state)}: ${formatInt(report.overall.filesIn(state))} '
                                '(${formatBytes(report.overall.bytesIn(state))})',
                              ),
                              Text(backupStateHint(state), style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              if (pending > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '${plural(pending, 'arquivo ainda não teve', 'arquivos ainda não tiveram')} o conteúdo conferido'
                  '${hash?.running ?? false ? '' : ' (conecte o dispositivo para conferir)'}.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
            const SizedBox(height: 12),
            const HashProgressBar(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => ref.read(navigationIndexProvider.notifier).select(compareDestination),
                  icon: const Icon(Icons.compare_arrows),
                  label: const Text('Comparar dispositivos ou pastas'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Alert extends StatelessWidget {
  const _Alert({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.travel_explore, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('Bem-vindo ao FotoAtlas', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              const Text(
                'Descubra o que você tem em cada HD, pendrive e celular, o que já tem backup e o que ainda falta — '
                'sem alterar nenhum arquivo.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar dispositivo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
