import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../features/compare/compare_page.dart';
import '../features/devices/devices_page.dart';
import '../features/home/home_page.dart';
import '../features/library/library_page.dart';
import '../features/placeholder/coming_soon_page.dart';
import '../features/settings/settings_page.dart';
import 'providers.dart';
import '../l10n/strings.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon, this.builder);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() builder;
}

final _destinations = [
  _Destination('Início', Icons.home_outlined, Icons.home, () => const HomePage()),
  _Destination('Biblioteca', Icons.photo_library_outlined, Icons.photo_library, () => const LibraryPage()),
  _Destination('Dispositivos', Icons.storage_outlined, Icons.storage, () => const DevicesPage()),
  _Destination('Comparar', Icons.compare_arrows_outlined, Icons.compare_arrows, () => const ComparePage()),
  _Destination(
    'Tarefas',
    Icons.task_alt_outlined,
    Icons.task_alt,
    () => const ComingSoonPage(
      title: 'Tarefas',
      description: 'Cópias em andamento e o histórico completo de tudo o que foi gravado.',
      phase: 'Fase 5',
    ),
  ),
  _Destination('Configurações', Icons.settings_outlined, Icons.settings, () => const SettingsPage()),
];

/// Índice do destino "Dispositivos" (atalhos do Início).
const devicesDestination = 2;

/// Índice do destino "Comparar".
const compareDestination = 3;

/// Navegação lateral com as 6 telas da spec (§3.2).
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // O helper caiu (fora do encerramento): avisa; o core já interrompeu o
    // scan/conferência de forma segura e reinicia o helper.
    ref.listen(helperStatusProvider, (previous, next) {
      if (next.value == HelperStatus.restarting && previous?.value != HelperStatus.restarting) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            key: ValueKey('helper-restarting'),
            content: Text(helperRestartingMessage),
            duration: Duration(seconds: 10),
          ),
        );
      }
    });
    final index = ref.watch(navigationIndexProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: wide,
            selectedIndex: index,
            onDestinationSelected: ref.read(navigationIndexProvider.notifier).select,
            labelType: wide ? NavigationRailLabelType.none : NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.travel_explore, size: 32, color: Theme.of(context).colorScheme.primary),
                  if (wide) ...[
                    const SizedBox(width: 8),
                    Text('FotoAtlas', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ],
              ),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _destinations[index].builder()),
        ],
      ),
    );
  }
}
