import 'package:flutter/material.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../app/theme.dart';

/// Situação de conexão com cor + ícone + texto (nunca só cor, spec §3.1).
class ConnectionBadge extends StatelessWidget {
  const ConnectionBadge(this.state, {super.key});

  final SourceState state;

  @override
  Widget build(BuildContext context) {
    final colors = StatusColors.of(context);
    final (icon, label, color) = switch (state) {
      SourceState.connected => (Icons.link, 'Conectado', colors.connected),
      SourceState.disconnected => (Icons.link_off, 'Desconectado', colors.disconnected),
      SourceState.ambiguous => (Icons.help_outline, 'Confirme qual unidade é esta', colors.attention),
    };
    final hint = switch (state) {
      SourceState.connected => 'Conectado agora: dá para escanear e conferir.',
      SourceState.disconnected =>
        'Desconectado: o FotoAtlas lembra o que viu no último escaneamento (nada foi apagado). '
            'Conecte para escanear de novo.',
      SourceState.ambiguous => 'Há mais de uma unidade parecida: confirme qual é a deste dispositivo.',
    };
    return Tooltip(
      message: hint,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

IconData sourceKindIcon(String kind) => switch (kind) {
  'external_hd' => Icons.save,
  'internal' => Icons.computer,
  'usb_stick' => Icons.usb,
  'memory_card' => Icons.sd_card,
  'phone' => Icons.smartphone,
  _ => Icons.folder,
};
