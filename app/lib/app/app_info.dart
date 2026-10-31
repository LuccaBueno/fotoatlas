/// Versão do app, definida pelo `tools\scripts\build-installer.ps1`
/// (`--dart-define=FOTOATLAS_VERSION=…`). Fora do instalador (desenvolvimento,
/// testes) não há versão.
const appVersion = String.fromEnvironment('FOTOATLAS_VERSION');

/// "Versão 1.0.0" ou "Versão de desenvolvimento".
String appVersionLabel([String version = appVersion]) =>
    version.isEmpty ? 'Versão de desenvolvimento' : 'Versão $version';
