import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../settings/settings_store.dart';
import '../util/clock.dart';

/// Versão "maior.menor.correção", com pré-lançamento opcional (`1.3.0-beta.1`).
/// Aceita `v` na frente; ignora `+build`. A ordem é a do Versionamento
/// Semântico: `1.2.1 < 1.3.0-beta.1 < 1.3.0-beta.2 < 1.3.0`.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, [this.preRelease]);
  final int major;
  final int minor;
  final int patch;

  /// Sufixo do pré-lançamento (`beta.1`); `null` numa versão estável.
  final String? preRelease;

  bool get isPreRelease => preRelease != null;

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+.*)?$');

  /// `null` se [text] não for uma versão.
  static AppVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4]);
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    return _comparePreRelease(preRelease, other.preRelease);
  }

  /// Sem sufixo vem depois de qualquer pré-lançamento da mesma versão; entre
  /// pré-lançamentos, parte a parte (números como números, e antes de texto).
  static int _comparePreRelease(String? a, String? b) {
    if (a == b) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    final pa = a.split('.');
    final pb = b.split('.');
    for (var i = 0; i < pa.length && i < pb.length; i++) {
      final na = int.tryParse(pa[i]);
      final nb = int.tryParse(pb[i]);
      final c = na != null && nb != null
          ? na.compareTo(nb)
          : na != null
          ? -1
          : nb != null
          ? 1
          : pa[i].compareTo(pb[i]);
      if (c != 0) return c;
    }
    return pa.length.compareTo(pb.length);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() => '$major.$minor.$patch${preRelease == null ? '' : '-$preRelease'}';
}

/// Última versão publicada, a página dela e, se a release tiver o instalador e
/// o `.sha256` dele, os endereços para "Atualizar agora".
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.pageUrl, this.installerUrl, this.checksumUrl});
  final AppVersion version;
  final Uri pageUrl;
  final Uri? installerUrl;
  final Uri? checksumUrl;

  /// Dá para baixar e conferir o instalador (senão, só "Baixar").
  bool get canInstall => installerUrl != null && checksumUrl != null;
}

/// Consulta a última versão publicada (`null` = não deu para saber).
typedef ReleaseFetcher = Future<ReleaseInfo?> Function();

/// Repositório oficial: só páginas dele são abertas.
const releasesPage = 'https://github.com/LuccaBueno/fotoatlas/releases';
final latestReleaseApi = Uri.parse('https://api.github.com/repos/LuccaBueno/fotoatlas/releases/latest');

/// A página de [version] no repositório oficial. Se o endereço que veio da
/// consulta não for dele, usa o endereço montado a partir da versão.
Uri releasePageFor(String? htmlUrl, AppVersion version) {
  if (htmlUrl != null && htmlUrl.startsWith('$releasesPage/')) {
    final uri = Uri.tryParse(htmlUrl);
    if (uri != null && uri.scheme == 'https' && uri.host == 'github.com') return uri;
  }
  return Uri.parse('$releasesPage/tag/v$version');
}

/// Nome do instalador publicado na release de [version].
String installerFileName(AppVersion version) => 'FotoAtlas-$version-instalador.exe';

/// Endereço de um arquivo da release [version] no repositório oficial. Sempre
/// montado aqui (nunca o endereço que veio na resposta).
Uri releaseAssetUrl(AppVersion version, String name) =>
    Uri.parse('$releasesPage/download/v$version/${Uri.encodeComponent(name)}');

/// Lê a resposta da API do GitHub (`releases/latest`). Só versões estáveis:
/// rascunho, release marcada como pré-lançamento ou tag com sufixo (`-beta.1`)
/// viram `null` — o aviso e o "Atualizar agora" nunca oferecem pré-lançamento.
ReleaseInfo? parseLatestRelease(String body) {
  final Object? json;
  try {
    json = jsonDecode(body);
  } on FormatException {
    return null;
  }
  if (json is! Map<String, Object?>) return null;
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  final version = tag is String ? AppVersion.tryParse(tag) : null;
  if (version == null || version.isPreRelease) return null;
  final html = json['html_url'];
  final assets = json['assets'];
  final names = {
    if (assets is List)
      for (final a in assets)
        if (a is Map<String, Object?> && a['name'] is String) a['name']! as String,
  };
  final installer = installerFileName(version);
  final installable = names.contains(installer) && names.contains('$installer.sha256');
  return ReleaseInfo(
    version: version,
    pageUrl: releasePageFor(html is String ? html : null, version),
    installerUrl: installable ? releaseAssetUrl(version, installer) : null,
    checksumUrl: installable ? releaseAssetUrl(version, '$installer.sha256') : null,
  );
}

/// Pede ao GitHub a última versão publicada. Não envia nada além do pedido em
/// si (sem versão, identificador ou dado do usuário). Qualquer falha (sem
/// internet, demora, resposta estranha) vira `null`, em silêncio.
Future<ReleaseInfo?> fetchLatestRelease({
  Uri? uri,
  Duration timeout = const Duration(seconds: 10),
  HttpClient Function()? clientFactory,
}) async {
  final client = (clientFactory ?? HttpClient.new)()..connectionTimeout = timeout;
  try {
    return await () async {
      final request = await client.getUrl(uri ?? latestReleaseApi);
      request.followRedirects = true;
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json')
        // O GitHub exige um User-Agent; vai só o nome do app.
        ..set(HttpHeaders.userAgentHeader, 'FotoAtlas');
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      return parseLatestRelease(await response.transform(utf8.decoder).join());
    }().timeout(timeout);
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Chaves no catálogo (tabela `settings`).
abstract final class UpdateSettingKeys {
  static const enabled = 'update.checkEnabled';
  static const lastCheckMs = 'update.lastCheckMs';
}

/// Resultado de "Procurar atualização agora".
sealed class UpdateCheckResult {
  const UpdateCheckResult();
}

/// Há versão mais nova publicada.
final class UpdateAvailable extends UpdateCheckResult {
  const UpdateAvailable(this.release);
  final ReleaseInfo release;
}

/// A versão em uso já é a mais nova publicada.
final class UpToDate extends UpdateCheckResult {
  const UpToDate(this.latest);
  final AppVersion latest;
}

/// Não deu para consultar (sem internet, GitHub fora do ar, resposta estranha).
final class UpdateCheckFailed extends UpdateCheckResult {
  const UpdateCheckFailed();
}

/// Versão de desenvolvimento: não há o que comparar.
final class UpdateCheckUnavailable extends UpdateCheckResult {
  const UpdateCheckUnavailable();
}

/// "Procurar versão nova ao abrir": no máximo uma consulta por dia, desligável.
/// Só diz se há versão nova; baixar e instalar só com o clique do usuário
/// (`update_download.dart`).
class UpdateChecker {
  UpdateChecker(this.settings, {ReleaseFetcher? fetch, int Function()? now})
    : _fetch = fetch ?? fetchLatestRelease,
      _now = now ?? nowMs;

  final SettingsStore settings;
  final ReleaseFetcher _fetch;
  final int Function() _now;

  static const interval = Duration(days: 1);

  /// Ligado por padrão.
  Future<bool> isEnabled() async => await settings.get(UpdateSettingKeys.enabled) != false;

  Future<void> setEnabled(bool enabled) => settings.set(UpdateSettingKeys.enabled, enabled);

  /// Se estiver ligado e a última consulta tiver mais de um dia, consulta e
  /// devolve a versão publicada quando ela é mais nova que [currentVersion].
  /// Sem versão (desenvolvimento), desligado, consultado há pouco ou falha:
  /// `null`.
  Future<ReleaseInfo?> checkIfDue(String currentVersion) async {
    final current = AppVersion.tryParse(currentVersion);
    if (current == null || !await isEnabled()) return null;
    final now = _now();
    final last = await settings.get(UpdateSettingKeys.lastCheckMs);
    if (last is int && now - last < interval.inMilliseconds && now >= last) return null;
    // Conta a tentativa (mesmo sem internet): no máximo uma por dia.
    await settings.set(UpdateSettingKeys.lastCheckMs, now);
    final ReleaseInfo? latest;
    try {
      latest = await _fetch();
    } on Object {
      return null;
    }
    return latest != null && _isStableNewer(latest, current) ? latest : null;
  }

  /// "Procurar atualização agora": consulta já, mesmo com a consulta ao abrir
  /// desligada (o usuário pediu), e conta como a consulta do dia.
  Future<UpdateCheckResult> checkNow(String currentVersion) async {
    final current = AppVersion.tryParse(currentVersion);
    if (current == null) return const UpdateCheckUnavailable();
    await settings.set(UpdateSettingKeys.lastCheckMs, _now());
    final ReleaseInfo? latest;
    try {
      latest = await _fetch();
    } on Object {
      return const UpdateCheckFailed();
    }
    if (latest == null || latest.version.isPreRelease) return const UpdateCheckFailed();
    return _isStableNewer(latest, current) ? UpdateAvailable(latest) : UpToDate(latest.version);
  }
}

/// Só uma versão estável mais nova que a em uso é oferecida (a em uso pode
/// ser um pré-lançamento: quem tem a `1.3.0-beta.2` recebe a `1.3.0`, nunca
/// a `1.2.1`).
bool _isStableNewer(ReleaseInfo latest, AppVersion current) => !latest.version.isPreRelease && latest.version > current;
