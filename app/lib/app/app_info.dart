import 'package:fotoatlas_core/fotoatlas_core.dart';

/// Versão do app, definida pelo `tools\scripts\build-installer.ps1`
/// (`--dart-define=FOTOATLAS_VERSION=…`). Fora do instalador (desenvolvimento,
/// testes) não há versão.
const appVersion = String.fromEnvironment('FOTOATLAS_VERSION');

/// "Versão 1.0.0", "Versão 1.3.0-beta.1 (pré-lançamento)" ou "Versão de
/// desenvolvimento".
String appVersionLabel([String version = appVersion]) {
  if (version.isEmpty) return 'Versão de desenvolvimento';
  final parsed = AppVersion.tryParse(version);
  return parsed != null && parsed.isPreRelease ? 'Versão $version (pré-lançamento)' : 'Versão $version';
}
