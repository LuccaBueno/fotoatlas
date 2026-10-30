import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/shell.dart' show tasksDestination;
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../tasks/copy_wizard.dart' show CopyPreviewView;

/// Resultado de um arquivo verificado, em palavras simples.
String checkResultLabel(String result) => switch (result) {
  CheckResult.unchanged => 'Inalterado',
  CheckResult.changedLegit => 'Alterado (foi editado: a data de modificação também mudou)',
  CheckResult.possiblyCorrupt => 'Possivelmente corrompido',
  CheckResult.unreadable => 'Não deu para ler agora',
  CheckResult.missing => 'Não está mais no lugar',
  _ => result,
};

/// Situação de uma rodada de verificação.
String runStatusLabel(IntegrityRunView r) => switch (r.status) {
  RunStatus.running => 'Verificando',
  RunStatus.paused when r.pausedByUser => 'Pausada',
  RunStatus.paused => 'Esperando',
  RunStatus.completed => r.hasProblems ? 'Concluída — encontrou problemas' : 'Concluída',
  RunStatus.cancelled => 'Cancelada',
  _ => r.status,
};

/// Abre "Verificar integridade" e, se o usuário confirmar, começa. Verificar
/// só lê os arquivos; não precisa de prévia de gravação.
Future<void> verifyFlow(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  List<VerifyEntry> entries = const [],
  List<int> contentIds = const [],
  bool phone = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final started = await showDialog<bool>(
    context: context,
    builder: (_) => VerifyDialog(title: title, entries: entries, contentIds: contentIds, phone: phone),
  );
  if (started != true) return;
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Verificação começou. Acompanhe em Tarefas.'),
      action: SnackBarAction(
        label: 'Ver em Tarefas',
        onPressed: () => ref.read(navigationIndexProvider.notifier).select(tasksDestination),
      ),
    ),
  );
}

/// "Verificar integridade": quanto vai ler e o que vai acontecer.
class VerifyDialog extends ConsumerStatefulWidget {
  const VerifyDialog({
    super.key,
    required this.title,
    this.entries = const [],
    this.contentIds = const [],
    this.phone = false,
  });

  final String title;
  final List<VerifyEntry> entries;
  final List<int> contentIds;
  final bool phone;

  @override
  ConsumerState<VerifyDialog> createState() => _VerifyDialogState();
}

class _VerifyDialogState extends ConsumerState<VerifyDialog> {
  /// Só o que não é conferido há mais de N dias (N da verificação periódica).
  bool _onlyStale = false;
  int _days = 90;
  VerifyEstimate? _estimate;
  Object? _error;
  bool _starting = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    ref.read(backendProvider).integritySchedule().then((s) {
      if (mounted) setState(() => _days = s.everyDays);
    }, onError: (Object _) {});
    _refresh();
  }

  VerifyRequest get _request =>
      VerifyRequest(entries: widget.entries, contentIds: widget.contentIds, olderThanDays: _onlyStale ? _days : null);

  Future<void> _refresh() async {
    final gen = ++_generation;
    setState(() => _estimate = null);
    try {
      final e = await ref.read(backendProvider).estimateVerify(_request);
      if (mounted && gen == _generation) setState(() => _estimate = e);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await ref.read(backendProvider).startVerify(_request);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final e = _estimate;
    Widget line(IconData icon, String text, {Color? color, Key? key}) => Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return AlertDialog(
      title: Text('Verificar integridade — ${widget.title}'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'O FotoAtlas lê cada arquivo de novo e compara com o conteúdo conferido antes, para descobrir se algo '
              'se estragou no disco. Só lê: nenhum arquivo é alterado, movido ou apagado.',
            ),
            const SizedBox(height: 12),
            if (widget.entries.isNotEmpty)
              SegmentedButton<bool>(
                key: const ValueKey('verify-scope'),
                segments: [
                  const ButtonSegment(value: false, label: Text('Tudo')),
                  ButtonSegment(value: true, label: Text('Só o que não é conferido há mais de $_days dias')),
                ],
                selected: {_onlyStale},
                onSelectionChanged: (s) {
                  setState(() => _onlyStale = s.single);
                  _refresh();
                },
              ),
            const SizedBox(height: 12),
            if (_error != null)
              line(Icons.error_outline, 'Não foi possível: $_error', color: colors.attention)
            else if (e == null)
              const LinearProgressIndicator()
            else ...[
              line(
                Icons.fact_check_outlined,
                e.files == 0
                    ? 'Nada para verificar agora.'
                    : 'Vai ler ${plural(e.files, 'arquivo', 'arquivos')} (${formatBytes(e.bytes)}).',
                key: const ValueKey('verify-summary'),
              ),
              if (widget.phone || e.phoneFiles > 0)
                line(
                  Icons.smartphone,
                  'Pelo cabo do celular a leitura é lenta e pode levar horas. Mantenha o celular desbloqueado e '
                  'conectado; dá para pausar e continuar depois. O celular só é verificado quando você pede.',
                  color: colors.attention,
                  key: const ValueKey('verify-phone-warning'),
                ),
              if (e.skippedDisconnected > 0)
                line(
                  Icons.link_off,
                  '${plural(e.skippedDisconnected, 'arquivo fica', 'arquivos ficam')} de fora: o dispositivo está '
                  'desconectado.',
                  color: colors.disconnected,
                ),
              if (e.notYetConferred > 0)
                line(
                  Icons.hourglass_empty,
                  '${plural(e.notYetConferred, 'arquivo ainda não teve', 'arquivos ainda não tiveram')} o conteúdo '
                  'conferido pela primeira vez: a conferência normal cuida deles antes.',
                  color: colors.unknown,
                ),
              line(
                Icons.pause_circle_outline,
                'Você pode pausar a qualquer momento em Tarefas. Se fechar o FotoAtlas no meio, ela continua de onde '
                'parou.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton.icon(
          key: const ValueKey('verify-start'),
          onPressed: e == null || e.files == 0 || _starting ? null : _start,
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Verificar'),
        ),
      ],
    );
  }
}

/// Seção da tela Tarefas: arquivos possivelmente corrompidos e as
/// verificações (em andamento e histórico).
class IntegritySection extends ConsumerWidget {
  const IntegritySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final runs = ref.watch(verifyRunsProvider).value ?? const <IntegrityRunView>[];
    final problems = ref.watch(integrityProblemsProvider).value ?? const <IntegrityProblem>[];
    if (runs.isEmpty && problems.isEmpty) return const SizedBox.shrink();
    final open = runs.where((r) => r.isOpen).toList();
    final done = runs.where((r) => !r.isOpen).take(10).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (problems.isNotEmpty) ...[
          Text(
            'Possivelmente corrompidos (${formatInt(problems.length)})',
            style: theme.textTheme.titleMedium,
            key: const ValueKey('problems-title'),
          ),
          const SizedBox(height: 4),
          const Text(
            'O conteúdo destes arquivos mudou, mas a data de modificação não: sinal de dano no disco. O FotoAtlas '
            'não mexeu neles. Restaure a partir de outra cópia conferida — a cópia boa é gravada ao lado, com outro '
            'nome; o arquivo danificado nunca é substituído nem apagado.',
          ),
          const SizedBox(height: 8),
          for (final p in problems) ProblemCard(key: ValueKey('problem-${p.instanceId}'), problem: p),
          const SizedBox(height: 16),
        ],
        if (runs.isNotEmpty) ...[
          Text('Verificações de integridade', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final r in [...open, ...done]) VerifyRunCard(key: ValueKey('run-${r.id}'), run: r),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Uma rodada de verificação: progresso, pausar/continuar e resultado.
class VerifyRunCard extends ConsumerWidget {
  const VerifyRunCard({super.key, required this.run});
  final IntegrityRunView run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final backend = ref.read(backendProvider);
    final progress = ref.watch(verifyProgressProvider).value;
    final live = progress != null && progress.runId == run.id && progress.running ? progress : null;
    final r = run;
    final (icon, color) = switch (r.status) {
      RunStatus.running => (Icons.fact_check_outlined, theme.colorScheme.primary),
      RunStatus.paused => (Icons.pause_circle_outline, colors.attention),
      RunStatus.completed when r.hasProblems => (Icons.report_outlined, colors.single),
      RunStatus.completed => (Icons.verified_outlined, colors.verified),
      _ => (Icons.cancel_outlined, colors.unknown),
    };
    final checked = live?.filesDone ?? r.filesChecked;
    final counts = live?.counts ?? r.counts;
    int n(String result) => counts[result] ?? 0;
    final summary = [
      if (n(CheckResult.unchanged) > 0) plural(n(CheckResult.unchanged), 'inalterado', 'inalterados'),
      if (n(CheckResult.possiblyCorrupt) > 0)
        plural(n(CheckResult.possiblyCorrupt), 'possivelmente corrompido', 'possivelmente corrompidos'),
      if (n(CheckResult.changedLegit) > 0) plural(n(CheckResult.changedLegit), 'editado', 'editados'),
      if (n(CheckResult.missing) > 0)
        plural(n(CheckResult.missing), 'não está mais no lugar', 'não estão mais no lugar'),
      if (n(CheckResult.unreadable) > 0) plural(n(CheckResult.unreadable), 'não deu para ler', 'não deu para ler'),
    ].join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${r.scheduled ? 'Verificação periódica' : 'Verificação'}: ${r.label}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${runStatusLabel(r)} · ${formatInt(checked)} de ${plural(r.filesTotal, 'arquivo', 'arquivos')}'
                        ' · ${formatDateTime(r.createdAt)}'
                        '${live != null && live.light ? ' · lendo devagar para não pesar no computador' : ''}',
                        key: ValueKey('run-status-${r.id}'),
                      ),
                    ],
                  ),
                ),
                if (r.status == RunStatus.running)
                  OutlinedButton.icon(
                    key: ValueKey('run-pause-${r.id}'),
                    onPressed: () => backend.pauseVerify(r.id),
                    icon: const Icon(Icons.pause),
                    label: const Text('Pausar'),
                  ),
                if (r.status == RunStatus.paused)
                  Tooltip(
                    message: r.includesPhone
                        ? 'Lê o celular de novo pelo cabo (devagar). Deixe-o desbloqueado.'
                        : 'Continua de onde parou.',
                    child: FilledButton.tonalIcon(
                      key: ValueKey('run-resume-${r.id}'),
                      onPressed: () => backend.resumeVerify(r.id),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Continuar'),
                    ),
                  ),
                if (r.isOpen) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => backend.cancelVerify(r.id), child: const Text('Cancelar')),
                ],
                if (r.filesChecked > 0)
                  TextButton(
                    key: ValueKey('run-details-${r.id}'),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => RunResultsDialog(run: r),
                    ),
                    child: const Text('Ver arquivos'),
                  ),
              ],
            ),
            if (r.isOpen && r.filesTotal > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: checked / r.filesTotal),
            ],
            if (live?.currentName != null) Text('Lendo: ${live!.currentName}', style: theme.textTheme.bodySmall),
            if (summary.isNotEmpty) ...[const SizedBox(height: 6), Text(summary)],
            if (r.message != null && r.isOpen) ...[
              const SizedBox(height: 4),
              Text(r.message!, style: TextStyle(color: colors.attention)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Arquivos de uma rodada, agrupados pelo resultado.
class RunResultsDialog extends ConsumerWidget {
  const RunResultsDialog({super.key, required this.run});
  final IntegrityRunView run;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    title: Text('Arquivos verificados — ${run.label}'),
    content: SizedBox(
      width: 640,
      height: 420,
      child: FutureBuilder<List<IntegrityCheckView>>(
        future: ref.read(backendProvider).verifyChecks(run.id),
        builder: (context, snap) {
          final list = snap.data;
          if (list == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            children: [
              for (final c in list)
                ListTile(
                  dense: true,
                  leading: Icon(_resultIcon(c.result), color: _resultColor(context, c.result)),
                  title: Text('${c.sourceName} › ${c.relPath.replaceAll('/', ' › ')}'),
                  subtitle: Text([checkResultLabel(c.result), ?c.reason].join(' — ')),
                ),
            ],
          );
        },
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Fechar'))],
  );
}

IconData _resultIcon(String result) => switch (result) {
  CheckResult.unchanged => Icons.check_circle_outline,
  CheckResult.possiblyCorrupt => Icons.report_outlined,
  CheckResult.changedLegit => Icons.edit_outlined,
  CheckResult.missing => Icons.help_outline,
  _ => Icons.block,
};

Color _resultColor(BuildContext context, String result) {
  final colors = StatusColors.of(context);
  return switch (result) {
    CheckResult.unchanged => colors.verified,
    CheckResult.possiblyCorrupt => colors.single,
    CheckResult.changedLegit => colors.probable,
    _ => colors.attention,
  };
}

/// Um arquivo possivelmente corrompido e de onde dá para restaurá-lo.
class ProblemCard extends ConsumerWidget {
  const ProblemCard({super.key, required this.problem});
  final IntegrityProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = StatusColors.of(context);
    final p = problem;
    final copies = p.otherCopies;
    final canWrite = p.connected && copies.every((c) => c.sourceId != p.sourceId || c.sourceKind != 'phone');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.report_outlined, color: colors.single),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: theme.textTheme.titleSmall),
                      Text(
                        '${p.sourceName} › ${p.relPath.replaceAll('/', ' › ')} · ${formatBytes(p.size)} · '
                        'encontrado em ${formatDateTime(p.detectedAt)}',
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: ValueKey('accept-${p.instanceId}'),
                  onPressed: () => _accept(context, ref),
                  child: const Text('A mudança é esperada…'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (copies.isEmpty)
              Text(
                'Nenhuma outra cópia conferida deste conteúdo é conhecida. Se você tiver outro backup, adicione-o e '
                'escaneie: se a foto estiver lá, ela aparece aqui.',
                style: TextStyle(color: colors.attention),
                key: ValueKey('no-copies-${p.instanceId}'),
              )
            else ...[
              Text(copies.length == 1 ? 'Outra cópia conferida:' : 'Outras cópias conferidas (${copies.length}):'),
              for (final c in copies)
                ListTile(
                  key: ValueKey('copy-${p.instanceId}-${c.instanceId}'),
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 8),
                  leading: Icon(
                    c.connected ? Icons.check_circle_outline : Icons.link_off,
                    color: c.connected ? colors.verified : colors.disconnected,
                  ),
                  title: Text('${c.sourceName} › ${c.relPath.replaceAll('/', ' › ')}'),
                  subtitle: Text(
                    [
                      if (!c.connected) 'desconectado: conecte para restaurar',
                      if (c.sameSource) 'no mesmo dispositivo',
                      if (!c.sameSource && c.samePhysicalDisk) 'no mesmo disco',
                      if (c.lastConfirmedAt != null)
                        '${c.recentlyVerified ? 'verificada' : 'conferida'} em ${formatDateTime(c.lastConfirmedAt!)}',
                    ].join(' · '),
                  ),
                  trailing: c.sameSource
                      ? null
                      : Tooltip(
                          message: !p.connected
                              ? 'Conecte "${p.sourceName}" para restaurar.'
                              : 'Copia esta cópia boa para a pasta do arquivo danificado, com conferência. Mostra a '
                                    'prévia antes; nada é substituído.',
                          child: FilledButton.tonal(
                            key: ValueKey('restore-${p.instanceId}-${c.instanceId}'),
                            onPressed: c.connected && canWrite ? () => restoreFlow(context, ref, p, c) : null,
                            child: const Text('Restaurar desta cópia…'),
                          ),
                        ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('A mudança é esperada?'),
        content: Text(
          'Use só se você (ou um programa seu) mudou "${problem.name}" de propósito sem mudar a data. O FotoAtlas '
          'passa a considerar o conteúdo atual como o certo e confere de novo. O arquivo não é alterado. '
          'Se a foto estiver estragada, prefira restaurar de outra cópia.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Voltar')),
          FilledButton(
            key: const ValueKey('accept-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aceitar o conteúdo atual'),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(backendProvider).acceptAsIs(problem.instanceId);
  }
}

/// Restaurar pela cópia segura (Fase 5): prévia → confirmar. Nada é gravado
/// antes do botão de confirmar.
Future<void> restoreFlow(BuildContext context, WidgetRef ref, IntegrityProblem problem, OtherCopy from) async {
  final messenger = ScaffoldMessenger.of(context);
  final started = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RestoreDialog(problem: problem, from: from),
  );
  if (started != true) return;
  messenger.showSnackBar(
    const SnackBar(content: Text('Restauração começou: a cópia é conferida antes de aparecer na pasta.')),
  );
}

class RestoreDialog extends ConsumerStatefulWidget {
  const RestoreDialog({super.key, required this.problem, required this.from});
  final IntegrityProblem problem;
  final OtherCopy from;

  @override
  ConsumerState<RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends ConsumerState<RestoreDialog> {
  CopyPreview? _preview;
  Object? _error;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    final backend = ref.read(backendProvider);
    backend
        .restoreRequest(widget.problem.instanceId, fromInstanceId: widget.from.instanceId)
        .then(backend.previewCopy)
        .then(
          (p) {
            if (mounted) setState(() => _preview = p);
          },
          onError: (Object e) {
            if (mounted) setState(() => _error = e is StateError ? e.message : e);
          },
        );
  }

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      await ref.read(backendProvider).startCopy(_preview!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _starting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final item = p == null || p.items.isEmpty ? null : p.items.first;
    return AlertDialog(
      title: Text('Restaurar "${widget.problem.name}"'),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Copia a cópia boa de "${widget.from.sourceName}" para a mesma pasta do arquivo danificado, com '
              'conferência do conteúdo. O arquivo danificado fica onde está, sem mudança: depois de conferir a foto '
              'restaurada, você decide o que fazer com ele.',
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text('Não dá para restaurar: $_error', key: const ValueKey('restore-error'))
            else if (p == null)
              const LinearProgressIndicator()
            else ...[
              if (item != null)
                Text(
                  'Vai gravar: ${p.destName} › ${item.dstRelPath.replaceAll('/', ' › ')}',
                  key: const ValueKey('restore-target'),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              const SizedBox(height: 8),
              CopyPreviewView(preview: p),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton.icon(
          key: const ValueKey('restore-confirm'),
          onPressed: p == null || !p.canStart || _starting ? null : _start,
          icon: const Icon(Icons.restore),
          label: const Text('Restaurar (cópia conferida)'),
        ),
      ],
    );
  }
}

/// Configurações › Verificação periódica.
class IntegritySettingsCard extends ConsumerWidget {
  const IntegritySettingsCard({super.key});

  static const _choices = [30, 90, 180, 365];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = ref.watch(integrityScheduleProvider).value;
    Future<void> save(IntegritySchedule next) async {
      await ref.read(backendProvider).setIntegritySchedule(next);
      ref.invalidate(integrityScheduleProvider);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verificação periódica', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'De tempos em tempos, o FotoAtlas lê de novo os arquivos dos discos conectados para descobrir se algo '
              'se estragou. É leve: lê devagar e espera quando o FotoAtlas está escaneando, conferindo, copiando ou '
              'reorganizando. Só lê; nada é alterado. Celulares nunca são verificados sozinhos — só quando você pede, '
              'no cartão do celular em Dispositivos.',
            ),
            const SizedBox(height: 8),
            if (s == null)
              const LinearProgressIndicator()
            else ...[
              SwitchListTile(
                key: const ValueKey('schedule-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Verificar periodicamente'),
                value: s.enabled,
                onChanged: (v) => save(IntegritySchedule(enabled: v, everyDays: s.everyDays)),
              ),
              Row(
                children: [
                  const Text('Verificar de novo o que não é conferido há mais de '),
                  DropdownButton<int>(
                    key: const ValueKey('schedule-days'),
                    value: _choices.contains(s.everyDays) ? s.everyDays : null,
                    hint: Text('${s.everyDays} dias'),
                    items: [
                      for (final d in _choices) DropdownMenuItem(value: d, child: Text(d == 365 ? '1 ano' : '$d dias')),
                    ],
                    onChanged: s.enabled ? (d) => save(IntegritySchedule(everyDays: d!)) : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
