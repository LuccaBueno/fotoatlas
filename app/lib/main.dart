import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'app/backend.dart';
import 'app/providers.dart';
import 'app/shell.dart';
import 'app/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FotoAtlasApp());
}

/// Abre o core (catálogo, helper, monitor de dispositivos) e mostra o app.
class FotoAtlasApp extends StatefulWidget {
  const FotoAtlasApp({super.key, this.openCore});

  /// Substituível em testes.
  final Future<FotoAtlasCore> Function()? openCore;

  @override
  State<FotoAtlasApp> createState() => _FotoAtlasAppState();
}

class _FotoAtlasAppState extends State<FotoAtlasApp> {
  late final Future<FotoAtlasCore> _core =
      (widget.openCore ?? () => FotoAtlasCore.open(monitor: true, autoHash: true, backupOnOpen: true))();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Ao fechar a janela: pausa scans em andamento e fecha o catálogo.
    _lifecycle = AppLifecycleListener(
      onExitRequested: () async {
        try {
          await (await _core).close();
        } on Object {
          // Fechar não pode impedir a saída.
        }
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  MaterialApp _app(Widget home) => MaterialApp(
    title: 'FotoAtlas',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: home,
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
          overrides: [backendProvider.overrideWithValue(CoreBackend(core))],
          child: _app(const AppShell()),
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
