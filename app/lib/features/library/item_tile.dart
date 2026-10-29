import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../l10n/format.dart';
import '../../l10n/strings.dart';
import '../../widgets/backup_state.dart';
import 'library_controller.dart';
import 'library_strings.dart';

/// Miniatura em cache; enquanto não chega (ou se não deu), um ícone do tipo.
class Thumbnail extends ConsumerWidget {
  const Thumbnail({super.key, required this.contentId, required this.mediaType, this.size = 160});
  final int contentId;
  final String? mediaType;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          mediaType == 'video' ? Icons.movie_outlined : Icons.image_outlined,
          color: scheme.onSurfaceVariant,
          size: size / 4,
        ),
      ),
    );
    return FutureBuilder<String?>(
      future: ref.read(thumbnailCacheProvider).get(contentId),
      builder: (context, snap) {
        final path = snap.data;
        if (path == null) return placeholder;
        return Image.file(
          File(path),
          fit: BoxFit.cover,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => placeholder,
        );
      },
    );
  }
}

/// Quadrinho da galeria: miniatura, hora (na linha do tempo), situação de
/// backup, vídeo e "hora incerta" — sempre com ícone + texto/tooltip.
class ItemTile extends ConsumerWidget {
  const ItemTile({
    super.key,
    required this.contentId,
    required this.size,
    required this.selected,
    required this.focused,
    required this.showTime,
    required this.onTap,
    required this.onToggle,
  });

  final int contentId;
  final double size;
  final bool selected;
  final bool focused;
  final bool showTime;
  final void Function(bool ctrl, bool shift) onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cache = ref.read(libraryItemCacheProvider);
    final item = cache.peek(contentId);
    if (item == null) {
      return FutureBuilder<LibraryItem?>(
        future: cache.get(contentId),
        builder: (context, snap) => _build(context, snap.data),
      );
    }
    return _build(context, item);
  }

  Widget _build(BuildContext context, LibraryItem? item) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final local = item?.local;
    final tooltip = item == null
        ? ''
        : [
            item.name,
            if (local != null) formatWallDateTime(local),
            if (item.make != null || item.model != null) cameraLabel('${item.make ?? ''}\u0001${item.model ?? ''}'),
            if (item.uncertain) 'Hora incerta',
          ].join('\n');
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: () {
          final keys = HardwareKeyboard.instance;
          onTap(keys.isControlPressed, keys.isShiftPressed);
        },
        child: Container(
          key: ValueKey('tile-$contentId'),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: selected ? scheme.primary : (focused ? scheme.outline : Colors.transparent),
              width: selected ? 3 : 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Thumbnail(contentId: contentId, mediaType: item?.mediaType, size: size),
                    if (item != null && item.mediaType == 'video')
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: _Pill(
                          icon: Icons.play_arrow,
                          text: item.durationMs == null ? 'Vídeo' : formatVideoLength(item.durationMs!),
                          tooltip: item.durationMs == null
                              ? 'Vídeo'
                              : 'Vídeo de ${formatVideoLength(item.durationMs!)}',
                        ),
                      ),
                    if (item != null && item.uncertain)
                      const Positioned(
                        left: 4,
                        bottom: 4,
                        child: _Pill(
                          icon: Icons.help_outline,
                          text: 'hora incerta',
                          tooltip:
                              'Hora incerta: não dá para ter certeza de quando foi tirada (ex.: veio só da data do '
                              'arquivo, que muda quando ele é copiado). Abra os detalhes para confirmar ou corrigir.',
                        ),
                      ),
                    if (item != null)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Tooltip(
                          message: backupStateItemHint(item.backup, item.places),
                          child: CircleAvatar(
                            radius: 11,
                            backgroundColor: scheme.surface.withValues(alpha: 0.85),
                            child: Icon(
                              backupStateIcon(item.backup),
                              size: 16,
                              color: backupStateColor(context, item.backup),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      left: 2,
                      top: 2,
                      child: Tooltip(
                        message: 'Marcar ou desmarcar (Ctrl+clique e Shift+clique também marcam)',
                        waitDuration: const Duration(milliseconds: 600),
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Checkbox(
                            semanticLabel: 'Marcar (Ctrl+clique e Shift+clique também marcam)',
                            value: selected,
                            onChanged: (_) => onToggle(),
                            visualDensity: VisualDensity.compact,
                            side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.6)),
                            fillColor: WidgetStateProperty.resolveWith(
                              (s) => s.contains(WidgetState.selected)
                                  ? scheme.primary
                                  : scheme.surface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (showTime)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                  child: Text(
                    local == null ? '—' : formatClock(local),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: item?.uncertain ?? false ? scheme.error : scheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, required this.tooltip});
  final IconData icon;
  final String text;
  final String tooltip;

  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: _pill());

  Widget _pill() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );
}
