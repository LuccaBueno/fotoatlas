import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../settings/settings_store.dart';

/// Chaves no catálogo (tabela `settings`).
abstract final class MapSettingKeys {
  /// Mapa online (OpenStreetMap) ligado pelo usuário. Padrão: desligado.
  static const online = 'map.onlineEnabled';
}

/// Imagens do mapa online (OpenStreetMap), só depois que o usuário liga em
/// Configurações (ADR 0026). Cada pedido leva só o nível de aproximação e a
/// posição do quadrado do mapa (z/x/y) — nunca o local de uma foto, nome de
/// arquivo ou dado do catálogo. Desligado, nenhum pedido sai do computador.
class OnlineMapTiles {
  OnlineMapTiles(
    this.settings, {
    this.urlTemplate = osmTemplate,
    this.userAgent = 'FotoAtlas (+https://github.com/LuccaBueno/fotoatlas)',
    this.timeout = const Duration(seconds: 10),
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  static const osmTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Nível máximo que o OpenStreetMap serve.
  static const maxZoom = 19;

  final SettingsStore settings;
  final String urlTemplate;

  /// A política de uso do OpenStreetMap exige identificar o app.
  final String userAgent;
  final Duration timeout;
  final HttpClient Function() _clientFactory;
  HttpClient? _client;
  bool _enabled = false;

  final _cache = <String, Uint8List>{};
  final _inFlight = <String, Future<Uint8List?>>{};
  static const _cacheSize = 400;

  /// Lê a escolha do usuário (e a guarda para os pedidos).
  Future<bool> isEnabled() async => _enabled = await settings.get(MapSettingKeys.online) == true;

  Future<void> setEnabled(bool enabled) async {
    await settings.set(MapSettingKeys.online, enabled);
    _enabled = enabled;
    if (!enabled) {
      _cache.clear();
      _client?.close(force: true);
      _client = null;
    }
  }

  /// Imagem PNG do quadrado z/x/y, ou `null` (desligado, sem internet, erro).
  /// Desligado, retorna sem fazer pedido nenhum.
  Future<Uint8List?> tile(int z, int x, int y) {
    if (!_enabled || z < 0 || z > maxZoom) return Future.value(null);
    final n = 1 << z;
    if (y < 0 || y >= n) return Future.value(null);
    final key = '$z/${x % n}/$y';
    final hit = _cache.remove(key);
    if (hit != null) {
      _cache[key] = hit;
      return Future.value(hit);
    }
    return _inFlight[key] ??= _fetch(z, x % n, y, key).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<Uint8List?> _fetch(int z, int x, int y, String key) async {
    final uri = Uri.parse(urlTemplate.replaceAll('{z}', '$z').replaceAll('{x}', '$x').replaceAll('{y}', '$y'));
    try {
      return await () async {
        final client = _client ??= _clientFactory()..connectionTimeout = timeout;
        final request = await client.getUrl(uri);
        request.headers.set(HttpHeaders.userAgentHeader, userAgent);
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok || response.headers.contentType?.primaryType != 'image') {
          await response.drain<void>();
          return null;
        }
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
          if (builder.length > 2 << 20) return null;
        }
        final bytes = builder.takeBytes();
        // Desligado durante o pedido: não guarda.
        if (!_enabled) return null;
        _cache[key] = bytes;
        if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
        return bytes;
      }().timeout(timeout);
    } on Object {
      return null;
    }
  }

  void close() {
    _client?.close(force: true);
    _client = null;
  }
}
