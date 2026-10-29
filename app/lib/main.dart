import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'app/backend.dart';
import 'app/close_confirm_dialog.dart';
import 'app/demo_mode.dart';
import 'app/library_backend.dart';
import 'app/providers.dart';
import 'app/shell.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FotoAtlasApp());
}

/// Abre o core (catálogo, helper, monitor de dispositivos) e mostra o app.
class FotoAtlasApp extends StatefulWidget {
  const FotoAtlasApp({super.key, this.openCore, this.demoMode, this.firstRunGuide = true});

  /// Mostra o guia de primeiros passos se ainda não foi visto (testes desligam).
  final bool firstRunGuide;

  /// Substituível em testes.
  final Future<FotoAtlasCore> Function()? openCore;

  /// Padrão: `FOTOATLAS_DEMO` (definido pelo `run-app.ps1`).
  final DemoMode? demoMode;

  /// Prazo máximo do encerramento: depois disso o app sai de qualquer jeito
  /// (o que ficou pela metade é recuperável ao abrir de novo).
  static const exitDeadline = Duration(seconds: 12);

  @override
  State<FotoAtlasApp> createState() => FotoAtlasAppState();
}

class FotoAtlasAppState extends State<FotoAtlasApp> {
  late final Future<FotoAtlasCore> _core =
      (widget.openCore ??
      () => FotoAtlasCore.open(monitor: true, autoHash: true, autoMetadata: true, backupOnOpen: true))();
  late final AppLifecycleListener _lifecycle;
  late final DemoMode _demo = widget.demoMode ?? DemoMode.fromEnvironment();

  /// Etapas do encerramento em andamento (`null` = não está fechando).
  List<ShutdownStep>? _closingSteps;
  Future<AppExitResponse>? _exit;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: requestExit);
  }

  /// Ao fechar a janela: se houver tarefas em andamento, pergunta antes
  /// ("Continuar trabalhando" é o padrão); depois mostra "Encerrando com
  /// segurança…", pausa o que estiver em andamento e fecha o catálogo. Uma
  /// vez confirmado, sempre termina com "sair", mesmo que o core não responda
  /// a tempo. Clicar no X de novo não abre outra pergunta nem recomeça.
  Future<AppExitResponse> requestExit() => _exit ??= _confirmAndShutdown();

  Future<AppExitResponse> _confirmAndShutdown() async {
    FotoAtlasCore? core;
    try {
      core = await _core.timeout(const Duration(seconds: 2));
    } on Object {
      // Core não abriu (ou travou abrindo): nada a pausar.
    }
    if (core != null) {
      final List<RunningTask> tasks;
      try {
        tasks = await core.runningTasks().timeout(const Duration(seconds: 1));
      } on Object {
        return _shutdown(core);
      }
      final context = _navigatorKey.currentContext;
      if (tasks.isNotEmpty && context != null && context.mounted) {
        final close = await showDialog<bool>(
          context: context,
          builder: (_) => CloseConfirmDialog(tasks: tasks, demoMode: _demo),
        );
        if (close != true) {
          _exit = null; // o próximo X pergunta de novo
          return AppExitResponse.cancel;
        }
      }
    }
    return _shutdown(core);
  }

  Future<AppExitResponse> _shutdown(FotoAtlasCore? core) async {
    if (mounted) setState(() => _closingSteps = const []);
    try {
      await core
          ?.close(onProgress: (steps) => mounted ? setState(() => _closingSteps = steps) : null)
          .timeout(FotoAtlasApp.exitDeadline);
    } on Object {
      // Fechar não pode impedir a saída.
    }
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  // Só a tela principal usa a chave do navegador: com a mesma chave na tela
  // de abertura, o Flutter reaproveitaria o navegador (e a página) dela.
  MaterialApp _app(Widget home, {GlobalKey<NavigatorState>? navigatorKey}) => MaterialApp(
    title: 'FotoAtlas',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: home,
    navigatorKey: navigatorKey,
    builder: (context, child) {
      // A faixa fica acima do navegador: visível também com diálogos abertos.
      if (_demo != DemoMode.off) {
        child = Column(
          children: [
            DemoBanner(mode: _demo),
            Expanded(child: child!),
          ],
        );
      }
      final steps = _closingSteps;
      if (steps == null) return child!;
      return Stack(
        children: [
          child!,
          Positioned.fill(
            child: _ClosingOverlay(steps: steps, demoMode: _demo),
          ),
        ],
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FotoAtlasCore>(
      future: _core,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _app(_StartupError(error: snapshot.error!));
        final core = snapshot.data;
        if (core == null) return _app(const _Splash());
        // O ProviderScope fica ACIMA do MaterialApp: diálogos e rotas (que o
        // Navigator põe fora da árvore da tela) também enxergam os providers.
        return ProviderScope(
          overrides: [
            backendProvider.overrideWithValue(CoreBackend(core)),
            libraryBackendProvider.overrideWithValue(CoreLibraryBackend(core)),
          ],
          child: _app(AppShell(firstRunGuide: widget.firstRunGuide), navigatorKey: _navigatorKey),
        );
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Abrindo o catálogo…')],
      ),
    ),
  );
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = switch (error) {
      CatalogInUseException() =>
        'O FotoAtlas já está aberto em outra janela (ou a linha de comando está usando o catálogo).',
      CatalogTooNewException() => error.toString(),
      _ => 'Não foi possível abrir o catálogo: $error',
    };
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Encerrando com segurança…" por cima de tudo, com o que falta.
class _ClosingOverlay extends StatelessWidget {
  const _ClosingOverlay({required this.steps, required this.demoMode});
  final List<ShutdownStep> steps;
  final DemoMode demoMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Bloqueia cliques enquanto encerra.
    return AbsorbPointer(
      key: const ValueKey('closing-overlay'),
      child: ColoredBox(
        color: theme.colorScheme.scrim.withValues(alpha: 0.5),
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text('Encerrando com segurança…', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final s in steps)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              s.done ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 18,
                              color: s.done ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s.label)),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(demoMode.closingMessage, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
