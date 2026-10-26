import 'package:flutter/material.dart';

/// Tema claro/escuro (Material 3) e cores semânticas dos estados.
abstract final class AppTheme {
  static const _seed = Color(0xFF1F6F8B);

  static ThemeData light() => _build(ColorScheme.fromSeed(seedColor: _seed));

  static ThemeData dark() => _build(ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark));

  static ThemeData _build(ColorScheme scheme) => ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    cardTheme: const CardThemeData(margin: EdgeInsets.zero),
    extensions: [StatusColors.forScheme(scheme)],
  );
}

/// Cores de estado. Sempre usadas junto com ícone e texto (nunca só cor).
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({required this.connected, required this.disconnected, required this.attention});

  factory StatusColors.forScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return StatusColors(
      connected: dark ? const Color(0xFF7BD88F) : const Color(0xFF1B7F3B),
      disconnected: scheme.outline,
      attention: dark ? const Color(0xFFFFC66D) : const Color(0xFF9A6200),
    );
  }

  final Color connected;
  final Color disconnected;
  final Color attention;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({Color? connected, Color? disconnected, Color? attention}) => StatusColors(
    connected: connected ?? this.connected,
    disconnected: disconnected ?? this.disconnected,
    attention: attention ?? this.attention,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      connected: Color.lerp(connected, other.connected, t)!,
      disconnected: Color.lerp(disconnected, other.disconnected, t)!,
      attention: Color.lerp(attention, other.attention, t)!,
    );
  }
}
