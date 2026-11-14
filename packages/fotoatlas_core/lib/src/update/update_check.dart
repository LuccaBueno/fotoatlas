import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../settings/settings_store.dart';
import '../util/clock.dart';

/// Versão "maior.menor.correção" (aceita `v` na frente; ignora sufixos como
/// `-beta` e `+build`).
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);
  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$');

  /// `null` se [text] não for uma versão.
  static AppVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  int compareTo(AppVersion other) => major != other.major
      ? major.compareTo(other.major)
      : minor != other.minor
      ? minor.compareTo(other.minor)
      : patch.compareTo(other.patch);

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// Última versão publicada e a página dela.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.pageUrl});
  final AppVersion version;
  final Uri pageUrl;
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

/// Lê a resposta da API do GitHub (`releases/latest`).
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
  if (version == null) return null;
  final html = json['html_url'];
  return ReleaseInfo(version: version, pageUrl: releasePageFor(html is String ? html : null, version));
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

/// "Procurar versão nova ao abrir": no máximo uma consulta por dia, desligável.
/// Nunca baixa nem instala nada; só diz se há versão nova.
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
    return latest != null && latest.version > current ? latest : null;
  }
}
