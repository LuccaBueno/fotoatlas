/// Imagens sintéticas para as fotos parecidas (Fase 9): "cenas" geradas por
/// semente (céu em degradê, formas coloridas), e variações da mesma cena —
/// redimensionada, recomprimida, cortada, rajada (formas um pouco deslocadas)
/// e mais clara. Nada vem de fotos reais.
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Variação de uma cena.
enum SceneVariant {
  /// A cena original (480×360, qualidade 90).
  original,

  /// Metade do tamanho (como uma foto enviada por mensagem).
  half,

  /// Recomprimida com qualidade baixa.
  lowQuality,

  /// Cortada 6% em cada borda (e de volta a 480×360).
  cropped,

  /// Rajada: as formas andaram alguns pixels.
  burst,

  /// Mais clara (edição de brilho).
  brighter,
}

/// JPEG de uma cena ([seed]) na variação pedida. Determinístico.
Uint8List sceneJpeg(int seed, [SceneVariant variant = SceneVariant.original]) {
  final base = _scene(seed, shift: variant == SceneVariant.burst ? 10 : 0);
  final img.Image out;
  var quality = 90;
  switch (variant) {
    case SceneVariant.original:
    case SceneVariant.burst:
      out = base;
    case SceneVariant.half:
      out = img.copyResize(
        base,
        width: base.width ~/ 2,
        height: base.height ~/ 2,
        interpolation: img.Interpolation.average,
      );
    case SceneVariant.lowQuality:
      out = base;
      quality = 25;
    case SceneVariant.cropped:
      final dx = (base.width * 0.06).round();
      final dy = (base.height * 0.06).round();
      final c = img.copyCrop(base, x: dx, y: dy, width: base.width - 2 * dx, height: base.height - 2 * dy);
      out = img.copyResize(c, width: base.width, height: base.height, interpolation: img.Interpolation.linear);
    case SceneVariant.brighter:
      out = img.adjustColor(base.clone(), brightness: 1.15);
  }
  return img.encodeJpg(out, quality: quality);
}

/// Imagem de uma cor só (lisa: sem informação para comparar).
Uint8List flatJpeg(int r, int g, int b) {
  final im = img.Image(width: 320, height: 240);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return img.encodeJpg(im, quality: 90);
}

img.Image _scene(int seed, {int shift = 0}) {
  final rnd = math.Random(seed);
  const w = 480;
  const h = 360;
  final im = img.Image(width: w, height: h);
  final top = [rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256)];
  final bottom = [rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256)];
  final horizon = h ~/ 3 + rnd.nextInt(h ~/ 3);
  final ground = [rnd.nextInt(200), rnd.nextInt(200), rnd.nextInt(200)];
  for (var y = 0; y < h; y++) {
    final t = y / h;
    final c = y < horizon
        ? img.ColorRgb8(
            (top[0] + (bottom[0] - top[0]) * t).round(),
            (top[1] + (bottom[1] - top[1]) * t).round(),
            (top[2] + (bottom[2] - top[2]) * t).round(),
          )
        : img.ColorRgb8(ground[0], ground[1], ground[2]);
    img.drawLine(im, x1: 0, y1: y, x2: w - 1, y2: y, color: c);
  }
  final shapes = 5 + rnd.nextInt(4);
  for (var s = 0; s < shapes; s++) {
    final color = img.ColorRgb8(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256));
    final x = rnd.nextInt(w) + shift;
    final y = rnd.nextInt(h);
    final size = 20 + rnd.nextInt(90);
    if (rnd.nextBool()) {
      img.fillCircle(im, x: x, y: y, radius: size ~/ 2, color: color);
    } else {
      img.fillRect(im, x1: x, y1: y, x2: x + size, y2: y + (size * 0.7).round(), color: color);
    }
  }
  return im;
}
