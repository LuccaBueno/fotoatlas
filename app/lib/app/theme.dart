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
  const StatusColors({
    required this.connected,
    required this.disconnected,
    required this.attention,
    required this.single,
    required this.probable,
    required this.verified,
    required this.independent,
    required this.unknown,
  });

  factory StatusColors.forScheme(ColorScheme scheme) {
    final dark = scheme.brightness == Brightness.dark;
    return StatusColors(
      connected: dark ? const Color(0xFF7BD88F) : const Color(0xFF1B7F3B),
      disconnected: scheme.outline,
      attention: dark ? const Color(0xFFFFC66D) : const Color(0xFF9A6200),
      single: dark ? const Color(0xFFFF8A80) : const Color(0xFFB3261E),
      probable: dark ? const Color(0xFFFFD54F) : const Color(0xFF8A6100),
      verified: dark ? const Color(0xFF7BD88F) : const Color(0xFF1B7F3B),
      independent: dark ? const Color(0xFF82B1FF) : const Color(0xFF1A5FB4),
      unknown: scheme.outline,
    );
  }

  final Color connected;
  final Color disconnected;
  final Color attention;

  /// Situações de backup (spec §3.1).
  final Color single;
  final Color probable;
  final Color verified;
  final Color independent;
  final Color unknown;

  static StatusColors of(BuildContext context) => Theme.of(context).extension<StatusColors>()!;

  @override
  StatusColors copyWith({
    Color? connected,
    Color? disconnected,
    Color? attention,
    Color? single,
    Color? probable,
    Color? verified,
    Color? independent,
    Color? unknown,
  }) => StatusColors(
    connected: connected ?? this.connected,
    disconnected: disconnected ?? this.disconnected,
    attention: attention ?? this.attention,
    single: single ?? this.single,
    probable: probable ?? this.probable,
    verified: verified ?? this.verified,
    independent: independent ?? this.independent,
    unknown: unknown ?? this.unknown,
  );

  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return StatusColors(
      connected: l(connected, other.connected),
      disconnected: l(disconnected, other.disconnected),
      attention: l(attention, other.attention),
      single: l(single, other.single),
      probable: l(probable, other.probable),
      verified: l(verified, other.verified),
      independent: l(independent, other.independent),
      unknown: l(unknown, other.unknown),
    );
  }
}
