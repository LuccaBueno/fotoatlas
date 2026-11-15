import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/app_info.dart';
import '../../app/close_confirm_dialog.dart';
import '../../app/providers.dart';
import '../../l10n/format.dart';

/// Versão em uso (substituível em testes; vazia fora do instalador).
final currentVersionProvider = Provider<String>((ref) => appVersion);

/// Abre a página da versão no navegador padrão. Só abre páginas do
/// repositório oficial (o endereço já vem conferido do core).
final releasePageOpenerProvider = Provider<Future<void> Function(Uri)>((ref) => _openInBrowser);

Future<void> _openInBrowser(Uri page) async {
  if (page.scheme != 'https' || !page.toString().startsWith('$releasesPage/')) return;
  try {
    await Process.start('explorer.exe', [page.toString()]);
  } on ProcessException {
    // Sem navegador: nada a fazer.
  }
}

/// Inicia o instalador já conferido e fecha o app com segurança (pausa o que
/// estiver em andamento, como no X). `false` = o instalador não iniciou e o app
/// continua aberto, sem nada alterado. O app (`main.dart`) substitui; o padrão
/// nunca inicia nada.
final updateInstallerLauncherProvider = Provider<Future<bool> Function(DownloadedInstaller)>(
  (ref) =>
      (_) async => false,
);

/// Versão nova a avisar na faixa. Ao abrir: apaga instaladores baixados em
/// vezes anteriores e consulta uma vez (o core limita a uma consulta por dia e
/// respeita a configuração). "Procurar atualização agora" também a preenche.
/// Falha = nenhum aviso.
final availableUpdateProvider = AsyncNotifierProvider<AvailableUpdate, ReleaseInfo?>(AvailableUpdate.new);

class AvailableUpdate extends AsyncNotifier<ReleaseInfo?> {
  @override
  Future<ReleaseInfo?> build() async {
    final backend = ref.read(backendProvider);
    try {
      await backend.cleanupUpdateDownloads();
    } on Object {
      // Fica para a próxima.
    }
    try {
      return await backend.checkForUpdate(ref.read(currentVersionProvider));
    } on Object {
      return null;
    }
  }

  void show(ReleaseInfo release) => state = AsyncData(release);

  /// "Agora não": esconde até a próxima abertura (ou até procurar de novo).
  void dismiss() => state = const AsyncData(null);
}

/// Faixa discreta no topo do conteúdo: "versão nova disponível", com
/// "Atualizar agora" (baixa, confere e instala depois de confirmar), "Baixar"
/// (abre a página da versão) e "Agora não". Nada acontece sem um clique.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(availableUpdateProvider).value;
    if (release == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('update-banner'),
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.system_update_alt, size: 18, color: scheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Versão ${release.version} do FotoAtlas disponível. Seus dados continuam onde estão ao atualizar.',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            if (release.canInstall)
              TextButton(
                key: const ValueKey('update-install'),
                onPressed: () => startUpdate(context, ref, release),
                child: const Text('Atualizar agora'),
              ),
            TextButton(
              key: const ValueKey('update-download'),
              onPressed: () => ref.read(releasePageOpenerProvider)(release.pageUrl),
              child: const Text('Baixar'),
            ),
            IconButton(
              key: const ValueKey('update-dismiss'),
              tooltip: 'Agora não',
              iconSize: 18,
              onPressed: () => ref.read(availableUpdateProvider.notifier).dismiss(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Atualizar agora": baixa com progresso (cancelável), pergunta antes de
/// fechar (listando as tarefas em andamento, que serão pausadas) e entrega ao
/// instalador. Em qualquer falha avisa e não muda nada.
Future<void> startUpdate(BuildContext context, WidgetRef ref, ReleaseInfo release) async {
  final installer = await showDialog<DownloadedInstaller>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UpdateDownloadDialog(release: release),
  );
  if (installer == null || !context.mounted) return;
  final backend = ref.read(backendProvider);
  List<RunningTask> tasks;
  try {
    tasks = await backend.runningTasks();
  } on Object {
    tasks = const [];
  }
  if (!context.mounted) return;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => UpdateConfirmDialog(version: installer.version, tasks: tasks),
  );
  if (confirmed != true || !context.mounted) return;
  final started = await ref.read(updateInstallerLauncherProvider)(installer);
  if (!started && context.mounted) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('update-start-failed'),
        title: const Text('Não deu para atualizar'),
        content: const Text(
          'O instalador não pôde ser iniciado (o arquivo baixado sumiu ou mudou). Nada foi alterado: o FotoAtlas '
          'continua aberto, na versão atual. Tente "Atualizar agora" de novo.',
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
      ),
    );
  }
}

/// Texto de cada falha do download. Em todas, o download foi apagado e nada
/// mais foi tocado.
String updateFailureMessage(UpdateDownloadFailure failure) => switch (failure) {
  UpdateDownloadFailure.network =>
    'Não foi possível baixar a atualização: sem internet, ou o GitHub não respondeu. Tente de novo mais tarde.',
  UpdateDownloadFailure.interrupted =>
    'O download foi interrompido antes de terminar. O que tinha sido baixado foi apagado. Tente de novo mais tarde.',
  UpdateDownloadFailure.hashMismatch =>
    'O arquivo baixado não é idêntico ao publicado (pode ter sido corrompido no caminho), por isso foi apagado sem '
        'ser instalado. Tente de novo mais tarde, ou use "Baixar" para abrir a página da versão.',
  UpdateDownloadFailure.checksumMissing =>
    'Esta versão foi publicada sem o arquivo de conferência, então o FotoAtlas não a instala sozinho. Use "Baixar" '
        'para abrir a página da versão.',
  UpdateDownloadFailure.disk =>
    'Não foi possível gravar o download na pasta temporária do Windows (disco cheio?). Libere espaço e tente de novo.',
  UpdateDownloadFailure.cancelled => 'Download cancelado.',
};

/// Baixando e conferindo o instalador, com "Cancelar". Devolve o instalador
/// conferido, ou `null` se cancelou ou falhou (a falha é mostrada aqui).
class UpdateDownloadDialog extends ConsumerStatefulWidget {
  const UpdateDownloadDialog({super.key, required this.release});
  final ReleaseInfo release;

  @override
  ConsumerState<UpdateDownloadDialog> createState() => _UpdateDownloadDialogState();
}

class _UpdateDownloadDialogState extends ConsumerState<UpdateDownloadDialog> {
  final _cancel = UpdateCancelToken();
  int _received = 0;
  int? _total;
  UpdateDownloadFailure? _failure;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final installer = await ref
          .read(backendProvider)
          .downloadUpdate(
            widget.release,
            cancel: _cancel,
            onProgress: (received, total) {
              if (mounted) {
                setState(() {
                  _received = received;
                  _total = total;
                });
              }
            },
          );
      if (mounted) Navigator.pop(context, installer);
    } on UpdateDownloadException catch (e) {
      if (!mounted) return;
      if (e.failure == UpdateDownloadFailure.cancelled) {
        Navigator.pop(context);
      } else {
        setState(() => _failure = e.failure);
      }
    } on Object {
      if (mounted) setState(() => _failure = UpdateDownloadFailure.network);
    }
  }

  @override
  void dispose() {
    _cancel.cancel(); // fechou a tela por outro caminho: para o download
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    if (failure != null) {
      return AlertDialog(
        key: const ValueKey('update-failed'),
        title: const Text('Não deu para atualizar'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            '${updateFailureMessage(failure)}\n\nNada foi alterado: o FotoAtlas continua na versão atual, com o '
            'catálogo e as configurações como estavam.',
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('update-failed-close'),
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      );
    }
    final total = _total;
    final verifying = total != null && total > 0 && _received >= total;
    return AlertDialog(
      key: const ValueKey('update-downloading'),
      title: Text('Baixando a versão ${widget.release.version}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              key: const ValueKey('update-progress'),
              value: verifying || total == null || total == 0 ? null : _received / total,
            ),
            const SizedBox(height: 8),
            Text(
              verifying
                  ? 'Conferindo se o arquivo baixado é idêntico ao publicado…'
                  : total == null
                  ? '${formatBytes(_received)} baixados'
                  : '${formatBytes(_received)} de ${formatBytes(total)}',
            ),
            const SizedBox(height: 12),
            const Text(
              'Do GitHub, onde o FotoAtlas é publicado. Nada é instalado sem você confirmar, e o FotoAtlas continua '
              'funcionando normalmente enquanto baixa.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(key: const ValueKey('update-cancel'), onPressed: _cancel.cancel, child: const Text('Cancelar')),
      ],
    );
  }
}

/// "Instalar agora?" depois do download conferido. "Agora não" é o padrão;
/// devolve `true` só em "Fechar e atualizar".
class UpdateConfirmDialog extends StatelessWidget {
  const UpdateConfirmDialog({super.key, required this.version, required this.tasks});
  final AppVersion version;
  final List<RunningTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      key: const ValueKey('update-confirm'),
      title: Text('Instalar a versão $version agora?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'O download foi conferido. Para instalar, o FotoAtlas fecha; o instalador abre sozinho, instala a '
              'versão $version e abre o FotoAtlas de novo. O catálogo e as configurações não são tocados.',
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Há tarefas em andamento:'),
              const SizedBox(height: 8),
              for (final t in tasks)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.pause_circle_outline, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(runningTaskLabel(t))),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              const Text(
                'Elas serão pausadas com segurança e continuam de onde pararam quando o FotoAtlas abrir de novo.',
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('update-later'),
          autofocus: true,
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          key: const ValueKey('update-close-and-install'),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Fechar e atualizar'),
        ),
      ],
    );
  }
}

final _updateEnabledProvider = FutureProvider<bool>((ref) => ref.watch(backendProvider).updateCheckEnabled());

/// Configurações → "Atualizações".
class UpdateSettingsCard extends ConsumerStatefulWidget {
  const UpdateSettingsCard({super.key});

  @override
  ConsumerState<UpdateSettingsCard> createState() => _UpdateSettingsCardState();
}

class _UpdateSettingsCardState extends ConsumerState<UpdateSettingsCard> {
  bool _checking = false;
  UpdateCheckResult? _result;

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    UpdateCheckResult result;
    try {
      result = await ref.read(backendProvider).checkForUpdateNow(ref.read(currentVersionProvider));
    } on Object {
      result = const UpdateCheckFailed();
    }
    if (!mounted) return;
    if (result is UpdateAvailable) ref.read(availableUpdateProvider.notifier).show(result.release);
    setState(() {
      _checking = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = ref.watch(_updateEnabledProvider).value;
    final result = _result;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Atualizações', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Ao abrir, no máximo uma vez por dia, o FotoAtlas pergunta ao GitHub (onde ele é publicado) qual é a '
              'versão mais nova. Nenhuma informação sua é enviada. Se houver versão nova, aparece um aviso com '
              '"Atualizar agora", que baixa o instalador oficial, confere se ele é idêntico ao publicado e, depois da '
              'sua confirmação, fecha o FotoAtlas, instala e abre de novo; e "Baixar", que abre a página da versão no '
              'navegador. O FotoAtlas nunca baixa nem instala nada sozinho, e atualizar não toca no catálogo nem nas '
              'configurações. Sem internet, nada acontece.',
            ),
            const SizedBox(height: 8),
            if (enabled == null)
              const LinearProgressIndicator()
            else
              SwitchListTile(
                key: const ValueKey('update-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Procurar versão nova ao abrir'),
                value: enabled,
                onChanged: (v) async {
                  await ref.read(backendProvider).setUpdateCheckEnabled(v);
                  ref.invalidate(_updateEnabledProvider);
                },
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('update-check-now'),
                  onPressed: _checking ? null : _checkNow,
                  icon: _checking
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('Procurar atualização agora'),
                ),
                if (result is UpdateAvailable && result.release.canInstall)
                  FilledButton(
                    key: const ValueKey('update-check-install'),
                    onPressed: () => startUpdate(context, ref, result.release),
                    child: const Text('Atualizar agora'),
                  ),
              ],
            ),
            if (result != null) ...[
              const SizedBox(height: 8),
              Text(key: const ValueKey('update-check-result'), switch (result) {
                UpdateAvailable(:final release) => 'Versão ${release.version} disponível.',
                UpToDate(:final latest) => upToDateMessage(ref.read(currentVersionProvider), latest),
                UpdateCheckFailed() =>
                  'Não foi possível consultar agora (sem internet, ou o GitHub não respondeu). Nada foi alterado.',
                UpdateCheckUnavailable() => 'Versão de desenvolvimento: não há versão publicada para comparar.',
              }),
            ],
          ],
        ),
      ),
    );
  }
}

/// Texto do "Procurar atualização agora" quando não há versão estável mais
/// nova. Num pré-lançamento, explica que só versões estáveis são oferecidas.
String upToDateMessage(String current, AppVersion latest) {
  final version = AppVersion.tryParse(current);
  if (version != null && version.isPreRelease) {
    return 'Você está usando um pré-lançamento ($version). Só versões estáveis são oferecidas: '
        'a mais nova publicada é a $latest; quando sair uma estável mais nova que a sua, ela aparece aqui.';
  }
  return 'Você já tem a versão mais nova ($latest).';
}
