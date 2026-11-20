import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../l10n/format.dart';
import 'library_controller.dart';

/// Contornos embutidos (Natural Earth, domínio público), lidos uma vez.
final mapContoursProvider = FutureProvider<MapContours>(
  (ref) async => MapContours.decode(await rootBundle.loadString('assets/map/contornos.json')),
);

/// Mapa online ligado em Configurações › Mapa (padrão: desligado).
final onlineMapProvider = FutureProvider<bool>(
  (ref) => ref.watch(libraryBackendProvider).onlineMapEnabled(),
  // Sem nova tentativa automática: com erro, o mapa fica sem internet.
  retry: (_, _) => null,
);

/// Mapa da Biblioteca (Fase 9.d): fotos e vídeos com local do filtro atual,
/// agrupados pela proximidade; "Ver as fotos desta área" vira filtro. Sem
/// internet por padrão: só os contornos embutidos (ADR 0026).
class LibraryMapView extends ConsumerStatefulWidget {
  const LibraryMapView({super.key, required this.filter, required this.index});
  final LibraryFilter filter;

  /// Muda quando a Biblioteca recarrega (recarrega os pontos junto).
  final LibraryIndex index;

  @override
  ConsumerState<LibraryMapView> createState() => _LibraryMapViewState();
}

class _LibraryMapViewState extends ConsumerState<LibraryMapView> {
  static const _minWorld = 256.0;
  static const _maxWorld = 256.0 * (1 << 18);

  MapPoints? _points;
  int _generation = 0;
  bool _fitted = false;

  // Câmera: centro em 0..1 de Mercator e tamanho do mundo em pixels.
  double _cx = 0.5, _cy = 0.5, _world = _minWorld;
  Size _size = Size.zero;

  List<MapCluster>? _clusters;
  double _clustersWorld = 0;

  _ShapePaths? _paths;
  final Map<String, ui.Image> _tiles = {};
  final Set<String> _loading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(LibraryMapView old) {
    super.didUpdateWidget(old);
    if (!identical(old.index, widget.index) || old.filter != widget.filter) _load();
  }

  @override
  void dispose() {
    for (final t in _tiles.values) {
      t.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final gen = ++_generation;
    final points = await ref.read(libraryBackendProvider).mapPoints(widget.filter);
    if (!mounted || gen != _generation) return;
    setState(() {
      _points = points;
      _clusters = null;
      if (!_fitted && _size != Size.zero) _fitAll();
    });
  }

  /// Enquadra todos os pontos (ou o mundo inteiro, se não há nenhum).
  void _fitAll() {
    final pts = _points;
    if (pts == null || _size == Size.zero) return;
    _fitted = true;
    if (pts.length == 0) {
      _setCamera(0.5, 0.5, _fitWorld(1, 1));
      return;
    }
    var x0 = 1.0, x1 = 0.0, y0 = 1.0, y1 = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final x = mercatorX(normalizeLon(pts.lon[i])), y = mercatorY(pts.lat[i]);
      x0 = math.min(x0, x);
      x1 = math.max(x1, x);
      y0 = math.min(y0, y);
      y1 = math.max(y1, y);
    }
    _fitBox(x0, y0, x1, y1);
  }

  void _fitBox(double x0, double y0, double x1, double y1) {
    final w = math.max(x1 - x0, 1e-6), h = math.max(y1 - y0, 1e-6);
    // Um ponto só (ou muito perto): aproxima até o nível de uma cidade.
    final world = math.min(_fitWorld(w * 1.3, h * 1.3), 256.0 * (1 << 12));
    _setCamera((x0 + x1) / 2, (y0 + y1) / 2, world);
  }

  double _fitWorld(double w, double h) =>
      math.min(_size.width / w, (_size.height - 60) / h).clamp(_minWorld, _maxWorld);

  void _setCamera(double cx, double cy, double world) {
    _world = world.clamp(_minWorld, _maxWorld);
    _cx = cx - cx.floorToDouble();
    final half = _size.height / 2 / _world;
    _cy = half >= 0.5 ? 0.5 : cy.clamp(half, 1 - half);
  }

  void _zoomAt(Offset focal, double factor) {
    final mx = _cx + (focal.dx - _size.width / 2) / _world;
    final my = _cy + (focal.dy - _size.height / 2) / _world;
    final world = (_world * factor).clamp(_minWorld, _maxWorld);
    setState(() {
      _setCamera(mx - (focal.dx - _size.width / 2) / world, my - (focal.dy - _size.height / 2) / world, world);
    });
  }

  Offset get _origin => Offset(_size.width / 2 - _cx * _world, _size.height / 2 - _cy * _world);

  /// Área visível no formato do filtro.
  List<double> get _visibleArea {
    final o = _origin;
    return mapAreaValues(
      west: mercatorLon(-o.dx / _world),
      east: mercatorLon((_size.width - o.dx) / _world),
      south: mercatorLat(math.min(1, (_size.height - o.dy) / _world)),
      north: mercatorLat(math.max(0, -o.dy / _world)),
    );
  }

  List<MapCluster> get _currentClusters {
    final pts = _points;
    if (pts == null) return const [];
    if (_clusters == null || _clustersWorld != _world) {
      _clusters = clusterMapPoints(pts, worldPx: _world);
      _clustersWorld = _world;
    }
    return _clusters!;
  }

  void _requestTiles(int z, Iterable<(int, int)> xy) {
    final backend = ref.read(libraryBackendProvider);
    for (final (x, y) in xy) {
      final key = '$z/$x/$y';
      if (_tiles.containsKey(key) || !_loading.add(key)) continue;
      backend
          .mapTile(z, x, y)
          .then((bytes) async {
            if (bytes == null) return;
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            if (!mounted) {
              frame.image.dispose();
              return;
            }
            setState(() {
              _tiles[key] = frame.image;
              if (_tiles.length > 300) _tiles.remove(_tiles.keys.first)?.dispose();
            });
          })
          // Imagem que não abre: fica só o contorno naquele quadrado.
          .catchError((Object _) {})
          .whenComplete(() => _loading.remove(key));
    }
  }

  void _tapCluster(MapCluster c) {
    if (c.count == 1) {
      ref.read(libraryControllerProvider.notifier).tap(c.firstId);
      return;
    }
    setState(() {
      final x0 = mercatorX(c.west), x1 = mercatorX(c.east);
      final y0 = mercatorY(c.north), y1 = mercatorY(c.south);
      final before = _world;
      _fitBox(x0, y0, x1, y1);
      // Pontos no mesmo lugar: aproxima um pouco mais a cada clique.
      if (_world <= before) _setCamera((x0 + x1) / 2, (y0 + y1) / 2, before * 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = ref.watch(onlineMapProvider).value ?? false;
    final contours = ref.watch(mapContoursProvider).value;
    if (contours != null && _paths?.contours != contours) _paths = _ShapePaths(contours);
    final pts = _points;
    final withPlace = pts?.length ?? 0;
    final withoutPlace = math.max(0, widget.index.length - widget.index.provisionalCount - withPlace);
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        if (size != _size) {
          _size = size;
          if (!_fitted && pts != null) {
            _fitAll();
          } else {
            _setCamera(_cx, _cy, _world);
          }
        }
        final o = _origin;
        final tiles = online ? _TileGrid.visible(_world, o, size) : null;
        if (tiles != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _requestTiles(tiles.z, tiles.xy());
          });
        }
        final clusters = _currentClusters;
        final bubbles = <Widget>[];
        for (final c in clusters) {
          for (final copy in _copies(o.dx, size.width)) {
            final p = Offset(o.dx + (c.x + copy) * _world, o.dy + c.y * _world);
            if (p.dx < -40 || p.dy < -40 || p.dx > size.width + 40 || p.dy > size.height + 40) continue;
            final r = 13 + 4 * math.log(c.count) / math.ln10;
            bubbles.add(
              Positioned(
                left: p.dx - r,
                top: p.dy - r,
                width: r * 2,
                height: r * 2,
                child: _Bubble(
                  key: ValueKey('map-cluster-${c.firstId}${copy == 0 ? '' : '@$copy'}'),
                  count: c.count,
                  onTap: () => _tapCluster(c),
                ),
              ),
            );
          }
        }
        return Listener(
          onPointerSignal: (e) {
            if (e is PointerScrollEvent) _zoomAt(e.localPosition, math.exp(-e.scrollDelta.dy / 300));
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleUpdate: (d) {
              if (d.scale != 1) {
                _zoomAt(d.localFocalPoint, d.scale / (_lastScale ?? 1));
                _lastScale = d.scale;
              }
              setState(
                () => _setCamera(_cx - d.focalPointDelta.dx / _world, _cy - d.focalPointDelta.dy / _world, _world),
              );
            },
            onScaleEnd: (_) => _lastScale = null,
            child: Stack(
              key: const ValueKey('library-map'),
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapPainter(
                      paths: _paths,
                      origin: o,
                      world: _world,
                      tiles: tiles,
                      images: _tiles,
                      scheme: theme.colorScheme,
                    ),
                  ),
                ),
                ...bubbles,
                Positioned(
                  left: 12,
                  top: 12,
                  right: 72,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Material(
                        color: theme.colorScheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Text(
                            pts == null
                                ? 'Carregando os locais…'
                                : '${plural(withPlace, 'foto ou vídeo', 'fotos e vídeos')} com local'
                                      '${withoutPlace > 0 ? ' · ${formatInt(withoutPlace)} sem local (não aparecem)' : ''}',
                            key: const ValueKey('map-summary'),
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('map-filter-area'),
                        onPressed: withPlace == 0
                            ? null
                            : () {
                                final c = ref.read(libraryControllerProvider.notifier);
                                c.setFilter(
                                  widget.filter.withCondition(FilterCondition(FilterKind.area, values: _visibleArea)),
                                );
                                c.setView(LibraryView.timeline);
                              },
                        icon: const Icon(Icons.crop_free),
                        label: const Text('Ver as fotos desta área'),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Column(
                    spacing: 6,
                    children: [
                      IconButton.filledTonal(
                        key: const ValueKey('map-zoom-in'),
                        tooltip: 'Aproximar',
                        onPressed: () => _zoomAt(size.center(Offset.zero), 2),
                        icon: const Icon(Icons.add),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('map-zoom-out'),
                        tooltip: 'Afastar',
                        onPressed: () => _zoomAt(size.center(Offset.zero), 0.5),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton.filledTonal(
                        key: const ValueKey('map-fit'),
                        tooltip: 'Ver todos os locais',
                        onPressed: () => setState(_fitAll),
                        icon: const Icon(Icons.fit_screen_outlined),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 8,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Material(
                      color: theme.colorScheme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Text(
                          online
                              ? 'Mapa online ligado (Configurações › Mapa) · © colaboradores do OpenStreetMap'
                              : 'Mapa sem internet: contornos de países e estados (Natural Earth). Os locais das fotos '
                                    'não saem do computador. Para ver ruas, ligue o mapa online em Configurações › Mapa.',
                          key: ValueKey(online ? 'map-attribution' : 'map-offline-note'),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  double? _lastScale;

  /// Cópias do mundo visíveis na horizontal (o mapa dá a volta).
  Iterable<int> _copies(double ox, double width) sync* {
    final first = (-ox / _world).floor();
    final last = ((width - ox) / _world).floor();
    for (var k = first; k <= last; k++) {
      yield k;
    }
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: count == 1 ? 'Abrir os detalhes' : '${plural(count, 'item', 'itens')} aqui · clique para aproximar',
      waitDuration: const Duration(milliseconds: 500),
      child: Material(
        color: scheme.primary,
        shape: CircleBorder(side: BorderSide(color: scheme.onPrimary, width: 2)),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: FittedBox(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(
                  count == 1 ? '' : formatInt(count),
                  style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Caminhos dos contornos em coordenadas 0..1 (montados uma vez).
class _ShapePaths {
  _ShapePaths(this.contours)
    : countries = [for (final s in contours.countries) (s, _path(s))],
      states = [for (final s in contours.states) (s, _path(s))];
  final MapContours contours;
  final List<(MapShape, Path)> countries;
  final List<(MapShape, Path)> states;

  static Path _path(MapShape s) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final r in s.rings) {
      if (r.length < 6) continue;
      path.moveTo(r[0], r[1]);
      for (var i = 2; i + 1 < r.length; i += 2) {
        path.lineTo(r[i], r[i + 1]);
      }
      path.close();
    }
    return path;
  }
}

/// Quadrados do mapa online visíveis no nível z.
class _TileGrid {
  _TileGrid(this.z, this.x0, this.x1, this.y0, this.y1, this.size);
  final int z, x0, x1, y0, y1;
  final double size;

  factory _TileGrid.visible(double world, Offset origin, Size view) {
    final z = (math.log(world / 256) / math.ln2).round().clamp(0, OnlineMapTiles.maxZoom);
    final size = world / (1 << z);
    final n = 1 << z;
    return _TileGrid(
      z,
      (-origin.dx / size).floor(),
      ((view.width - origin.dx) / size).floor(),
      math.max(0, (-origin.dy / size).floor()),
      math.min(n - 1, ((view.height - origin.dy) / size).floor()),
      size,
    );
  }

  Iterable<(int, int)> xy() sync* {
    final n = 1 << z;
    for (var y = y0; y <= y1; y++) {
      for (var x = x0; x <= x1; x++) {
        yield (x % n, y);
      }
    }
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.paths,
    required this.origin,
    required this.world,
    required this.tiles,
    required this.images,
    required this.scheme,
  });
  final _ShapePaths? paths;
  final Offset origin;
  final double world;
  final _TileGrid? tiles;
  final Map<String, ui.Image> images;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final dark = scheme.brightness == Brightness.dark;
    final ocean = dark ? const Color(0xFF15232E) : const Color(0xFFD5E6F0);
    final land = dark ? const Color(0xFF2B3329) : const Color(0xFFF1EFE6);
    final border = dark ? const Color(0xFF6E7A6B) : const Color(0xFF9A9784);
    canvas.drawRect(Offset.zero & size, Paint()..color = ocean);

    // Contornos sempre por baixo: sem internet (ou sem a imagem ainda) o mapa não fica em branco.
    final p = paths;
    if (p != null) {
      final first = (-origin.dx / world).floor();
      final last = ((size.width - origin.dx) / world).floor();
      final fill = Paint()..color = land;
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..color = border
        ..strokeWidth = 0.8 / world;
      final thin = Paint()
        ..style = PaintingStyle.stroke
        ..color = border.withValues(alpha: 0.55)
        ..strokeWidth = 0.5 / world;
      for (var k = first; k <= last; k++) {
        final ox = origin.dx + k * world;
        // Janela visível em 0..1 desta cópia.
        final vx0 = -ox / world, vx1 = (size.width - ox) / world;
        final vy0 = -origin.dy / world, vy1 = (size.height - origin.dy) / world;
        bool visible(MapShape s) =>
            s.bounds[2] >= vx0 && s.bounds[0] <= vx1 && s.bounds[3] >= vy0 && s.bounds[1] <= vy1;
        canvas
          ..save()
          ..translate(ox, origin.dy)
          ..scale(world);
        for (final (s, path) in p.countries) {
          if (visible(s)) canvas.drawPath(path, fill);
        }
        if (world >= 2048) {
          for (final (s, path) in p.states) {
            if (visible(s)) canvas.drawPath(path, thin);
          }
        }
        for (final (s, path) in p.countries) {
          if (visible(s)) canvas.drawPath(path, stroke);
        }
        canvas.restore();
      }
    }

    final t = tiles;
    if (t != null) {
      final n = 1 << t.z;
      final paint = Paint()..filterQuality = FilterQuality.medium;
      for (var y = t.y0; y <= t.y1; y++) {
        for (var x = t.x0; x <= t.x1; x++) {
          final img = images['${t.z}/${x % n}/$y'];
          if (img == null) continue;
          final dst = Rect.fromLTWH(origin.dx + x * t.size, origin.dy + y * t.size, t.size, t.size);
          canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), dst, paint);
        }
      }
    }
  }

  @override
  // As imagens do mapa online chegam no mesmo mapa: sempre redesenha (só quando a tela é refeita).
  bool shouldRepaint(_MapPainter old) => true;
}
