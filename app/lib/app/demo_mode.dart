import 'dart:io';

import 'package:flutter/material.dart';

/// Modo de demonstração, avisado pelo `run-app.ps1` em `FOTOATLAS_DEMO`.
enum DemoMode {
  /// Catálogo real.
  off,

  /// `-Demo` / `-CelularSimulado`: o catálogo temporário é descartado ao
  /// fechar; nada continua na próxima abertura.
  discarded,

  /// `-DemoPersistente`: pasta temporária fixa, mantida entre aberturas.
  persistent;

  static DemoMode fromEnvironment([Map<String, String>? env]) =>
      switch ((env ?? Platform.environment)['FOTOATLAS_DEMO']) {
        'descartavel' => DemoMode.discarded,
        'persistente' => DemoMode.persistent,
        _ => DemoMode.off,
      };

  /// O que acontece com as tarefas ao fechar (pergunta e "Encerrando…").
  String get closeMessage => this == DemoMode.discarded
      ? 'Modo demonstração: nada será mantido. Tudo é descartado ao fechar, e a próxima abertura começa do zero.'
      : 'Elas serão pausadas e continuam de onde pararam quando você abrir o FotoAtlas de novo.';

  String get closingMessage => this == DemoMode.discarded
      ? 'Leva só alguns segundos. Modo demonstração: nada será mantido, tudo é descartado ao fechar.'
      : 'Leva só alguns segundos. Nada se perde: o que estava em andamento continua de onde parou '
            'quando você abrir o FotoAtlas de novo.';
}

/// Faixa fixa no topo da janela em modo de demonstração.
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.mode});
  final DemoMode mode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final discarded = mode == DemoMode.discarded;
    return Material(
      key: const ValueKey('demo-banner'),
      color: discarded ? scheme.errorContainer : scheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.science_outlined,
              size: 18,
              color: discarded ? scheme.onErrorContainer : scheme.onTertiaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                discarded
                    ? 'Modo demonstração — tudo será descartado ao fechar'
                    : 'Modo demonstração — os dados ficam numa pasta temporária e são mantidos entre aberturas',
                style: TextStyle(color: discarded ? scheme.onErrorContainer : scheme.onTertiaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
