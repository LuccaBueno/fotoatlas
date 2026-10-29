import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import '../library/library_strings.dart';

class _DatesSettings {
  const _DatesSettings(this.gap, this.zone, this.priority, this.tools, this.corrections);
  final Duration gap;
  final String zone;
  final List<DateSource> priority;
  final ExternalTools tools;
  final List<ClockCorrection> corrections;
}

final _datesSettingsProvider = FutureProvider.autoDispose<_DatesSettings>((ref) async {
  ref.watch(libraryChangesProvider);
  final b = ref.watch(libraryBackendProvider);
  return _DatesSettings(b.momentGap, b.timezone, b.datePriority, b.tools, await b.corrections());
});

const _gaps = [30, 60, 120, 180, 240, 360, 720, 1440];
const _zones = [
  'America/Sao_Paulo',
  'America/Manaus',
  'America/Cuiaba',
  'America/Belem',
  'America/Fortaleza',
  'America/Recife',
  'America/Rio_Branco',
  'America/Noronha',
  'Europe/Lisbon',
  'UTC',
];

String _gapLabel(int minutes) =>
    minutes < 60 ? '$minutes min' : (minutes % 60 == 0 ? '${minutes ~/ 60} h' : '$minutes min');

/// Configurações › Datas e momentos (Fase 4).
class DatesSettingsCard extends ConsumerWidget {
  const DatesSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(_datesSettingsProvider);
    final s = data.value;
    if (s == null) return const SizedBox.shrink();
    final backend = ref.read(libraryBackendProvider);
    Future<void> run(Future<Object?> Function() action, String done) async {
      final messenger = ScaffoldMessenger.of(context);
      await action();
      ref.invalidate(_datesSettingsProvider);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    }

    return Card(
      key: const ValueKey('dates-settings'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Datas e momentos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Tudo aqui muda só o catálogo do FotoAtlas: os arquivos e os dados gravados neles nunca são alterados.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('Novo momento depois de um intervalo sem fotos de')),
                DropdownButton<int>(
                  key: const ValueKey('moment-gap'),
                  value: _gaps.contains(s.gap.inMinutes) ? s.gap.inMinutes : null,
                  hint: Text(_gapLabel(s.gap.inMinutes)),
                  items: [for (final g in _gaps) DropdownMenuItem(value: g, child: Text(_gapLabel(g)))],
                  onChanged: (g) => run(() async {
                    final r = await backend.setMomentGap(Duration(minutes: g!));
                    return r;
                  }, 'Momentos recalculados (os que você nomeou, juntou ou separou ficaram como estavam).'),
                ),
              ],
            ),
            Row(
              children: [
                const Expanded(child: Text('Fuso das fotos sem fuso gravado')),
                DropdownButton<String>(
                  key: const ValueKey('timezone'),
                  value: _zones.contains(s.zone) ? s.zone : null,
                  hint: Text(s.zone),
                  items: [for (final z in _zones) DropdownMenuItem(value: z, child: Text(z.replaceAll('_', ' ')))],
                  onChanged: (z) {
                    final zone = z!;
                    run(() => backend.setTimezone(zone), 'Horas recalculadas com o fuso ${zone.replaceAll('_', ' ')}.');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('De onde tirar a data, nesta ordem (a hora corrigida por você vale sempre acima de todas):'),
            const SizedBox(height: 4),
            for (var i = 0; i < s.priority.length; i++)
              ListTile(
                dense: true,
                leading: Text('${i + 1}.'),
                title: Text(_capitalize(dateSourceLabel(s.priority[i]))),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Subir',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0
                          ? null
                          : () => run(() {
                              final l = [...s.priority]..insert(i - 1, s.priority[i]);
                              l.removeAt(i + 1);
                              return backend.setDatePriority(l);
                            }, 'Ordem das datas atualizada.'),
                    ),
                    IconButton(
                      tooltip: 'Descer',
                      icon: const Icon(Icons.arrow_downward),
                      onPressed: i == s.priority.length - 1
                          ? null
                          : () => run(() {
                              final l = [...s.priority]..insert(i + 2, s.priority[i]);
                              l.removeAt(i);
                              return backend.setDatePriority(l);
                            }, 'Ordem das datas atualizada.'),
                    ),
                  ],
                ),
              ),
            const Divider(height: 32),
            Text('Correções de relógio', style: theme.textTheme.titleSmall),
            if (s.corrections.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Nenhuma. Para corrigir, use a Biblioteca › Mais ações › Corrigir o relógio de um dispositivo.',
                ),
              ),
            for (final c in s.corrections)
              ListTile(
                key: ValueKey('correction-${c.id}'),
                dense: true,
                leading: Icon(c.active ? Icons.schedule : Icons.undo),
                title: Text(
                  '${CaptureDevice(make: c.make, model: c.model, serial: c.bodySerial, items: 0).label}: ${c.describe()}',
                ),
                subtitle: Text(
                  [
                    if (c.createdAt != null) 'feita em ${formatDateTime(c.createdAt!)}',
                    if (c.undoneAt != null) 'desfeita em ${formatDateTime(c.undoneAt!)}',
                  ].join(' · '),
                ),
                trailing: c.active
                    ? TextButton(
                        onPressed: () => run(() => backend.undoCorrection(c.id), 'Correção desfeita.'),
                        child: const Text('Desfazer'),
                      )
                    : null,
              ),
            const Divider(height: 32),
            Text('Leitura dos dados das fotos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              s.tools.exiftool == null
                  ? 'Leitor de dados das fotos (ExifTool): não encontrado. As datas vêm do nome e da data do arquivo. '
                        'Em desenvolvimento, rode tools\\scripts\\get-tools.ps1; o instalador da versão final já o inclui.'
                  : 'Leitor de dados das fotos (ExifTool): encontrado.',
              key: const ValueKey('exiftool-status'),
            ),
            Text(
              s.tools.ffprobe == null
                  ? 'Leitor de vídeos (FFmpeg): não encontrado (vídeos sem duração e sem miniatura).'
                  : 'Leitor de vídeos (FFmpeg): encontrado.',
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => run(backend.retryMetadataErrors, 'Os itens com erro voltaram para a fila de leitura.'),
              child: const Text('Ler de novo os que deram erro'),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
