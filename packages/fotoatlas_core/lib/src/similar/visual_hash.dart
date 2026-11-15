import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Impressão visual de uma foto (spec §9, fotos parecidas), calculada a partir
/// da miniatura em cache — o arquivo de origem nem é aberto aqui, e nenhuma
/// imagem é gravada.
///
/// - [perceptual]: pHash de 64 bits (frequências baixas da DCT de uma grade
///   32×32 comparadas com a mediana). Resiste a redução, recompressão e
///   mudança de brilho.
/// - [gradient]: dHash de 64 bits (vizinho da direita mais claro?). Confirma
///   as sugestões mais fracas.
/// - [flat]: imagem quase lisa (tudo preto, céu sem nada): a impressão não tem
///   informação e nunca vira sugestão.
class VisualHash {
  const VisualHash(this.perceptual, this.gradient, {this.flat = false});
  final int perceptual;
  final int gradient;
  final bool flat;

  /// Versão do cálculo: se mudar, as impressões antigas são recalculadas.
  static const algorithm = 1;

  @override
  bool operator ==(Object other) =>
      other is VisualHash && other.perceptual == perceptual && other.gradient == gradient && other.flat == flat;

  @override
  int get hashCode => Object.hash(perceptual, gradient, flat);

  @override
  String toString() =>
      'VisualHash(${perceptual.toUnsigned(64).toRadixString(16)}, '
      '${gradient.toUnsigned(64).toRadixString(16)}${flat ? ', lisa' : ''})';
}

/// Desvio-padrão do brilho (0–255, grade 16×16) abaixo do qual a imagem é lisa.
const flatStdDev = 6.0;

/// Impressão visual a partir de tons de cinza ([gray]: [width] × [height], um
/// byte por pixel, linha a linha).
VisualHash visualHashFromGray(Uint8List gray, int width, int height) {
  if (width <= 0 || height <= 0 || gray.length < width * height) {
    throw ArgumentError('Imagem inválida: $width×$height com ${gray.length} bytes');
  }
  final perceptual = _pHash(shrinkGray(gray, width, height, 32, 32));
  final g = shrinkGray(gray, width, height, 9, 8);
  var gradient = 0;
  var bit = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++, bit++) {
      if (g[y * 9 + x] < g[y * 9 + x + 1]) gradient |= 1 << bit;
    }
  }
  final grid = shrinkGray(gray, width, height, 16, 16);
  var sum = 0.0;
  for (final v in grid) {
    sum += v;
  }
  final mean = sum / grid.length;
  var sq = 0.0;
  for (final v in grid) {
    sq += (v - mean) * (v - mean);
  }
  return VisualHash(perceptual, gradient, flat: math.sqrt(sq / grid.length) < flatStdDev);
}

/// Cossenos da DCT (8 frequências × 32 posições).
final _cos = () {
  final t = Float64List(8 * 32);
  for (var u = 0; u < 8; u++) {
    for (var x = 0; x < 32; x++) {
      t[u * 32 + x] = math.cos((2 * x + 1) * u * math.pi / 64);
    }
  }
  return t;
}();

int _pHash(Float64List g) {
  final rows = Float64List(32 * 8);
  for (var y = 0; y < 32; y++) {
    for (var u = 0; u < 8; u++) {
      var s = 0.0;
      for (var x = 0; x < 32; x++) {
        s += g[y * 32 + x] * _cos[u * 32 + x];
      }
      rows[y * 8 + u] = s;
    }
  }
  final coef = Float64List(64);
  for (var v = 0; v < 8; v++) {
    for (var u = 0; u < 8; u++) {
      var s = 0.0;
      for (var y = 0; y < 32; y++) {
        s += rows[y * 8 + u] * _cos[v * 32 + y];
      }
      coef[v * 8 + u] = s;
    }
  }
  // Sem o termo constante (brilho médio): só a "forma" da imagem.
  final ac = Float64List.fromList(coef.sublist(1))..sort();
  final median = ac[ac.length ~/ 2];
  var h = 0;
  for (var i = 1; i < 64; i++) {
    if (coef[i] > median) h |= 1 << i;
  }
  return h;
}

/// Reduz por média de área (cada célula = média dos pixels que ela cobre).
Float64List shrinkGray(Uint8List gray, int width, int height, int outW, int outH) {
  final out = Float64List(outW * outH);
  for (var oy = 0; oy < outH; oy++) {
    final y0 = oy * height / outH;
    final y1 = (oy + 1) * height / outH;
    for (var ox = 0; ox < outW; ox++) {
      final x0 = ox * width / outW;
      final x1 = (ox + 1) * width / outW;
      var total = 0.0;
      var weight = 0.0;
      for (var y = y0.floor(); y < y1.ceil() && y < height; y++) {
        final wy = math.min(y + 1, y1) - math.max(y, y0);
        if (wy <= 0) continue;
        for (var x = x0.floor(); x < x1.ceil() && x < width; x++) {
          final wx = math.min(x + 1, x1) - math.max(x, x0);
          if (wx <= 0) continue;
          total += gray[y * width + x] * wx * wy;
          weight += wx * wy;
        }
      }
      out[oy * outW + ox] = weight == 0 ? 0 : total / weight;
    }
  }
  return out;
}

/// Impressão de uma imagem codificada (JPEG, PNG…); `null` se não der para
/// decodificar. Só decodifica: nada é gravado.
VisualHash? visualHashFromBytes(Uint8List bytes) {
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } on Object {
    return null;
  }
  if (decoded == null || decoded.width == 0 || decoded.height == 0) return null;
  final gray = Uint8List(decoded.width * decoded.height);
  var i = 0;
  for (final p in decoded) {
    // Luminância (BT.601); transparência sobre fundo branco.
    final a = p.aNormalized.toDouble();
    final l = 0.299 * p.rNormalized + 0.587 * p.gNormalized + 0.114 * p.bNormalized;
    gray[i++] = ((l * a + (1 - a)) * 255).round().clamp(0, 255);
  }
  return visualHashFromGray(gray, decoded.width, decoded.height);
}

/// Impressão de um arquivo de imagem (a miniatura em cache); só lê.
VisualHash? visualHashFromFile(String path) {
  try {
    return visualHashFromBytes(File(path).readAsBytesSync());
  } on FileSystemException {
    return null;
  }
}

/// Bits diferentes entre duas impressões de 64 bits.
int hammingDistance(int a, int b) {
  var v = a ^ b;
  var n = 0;
  while (v != 0) {
    v &= v - 1;
    n++;
  }
  return n;
}
