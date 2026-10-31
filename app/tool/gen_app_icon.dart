// Gera o ícone do app (janela, barra de tarefas, executável e instalador) a
// partir da logo do menu lateral: o ícone `travel_explore` (globo com lupa,
// Material Icons, Apache 2.0) na cor primária do tema, sobre um quadrado
// arredondado na cor da superfície — como aparece no menu lateral.
//
// Uso (na pasta app\):
//   flutter test tool\gen_app_icon.dart
// Grava windows\runner\resources\app_icon.ico (16 a 256 px). O ícone gerado
// é versionado; rode de novo só se a logo ou as cores do tema mudarem.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/app/theme.dart';

/// Tamanhos que o Windows usa (100% a 300% de escala, Explorer e instalador).
const iconSizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256];

void main() {
  testWidgets('gera app_icon.ico', (tester) async {
    await tester.runAsync(() async {
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot == null) fail('FLUTTER_ROOT não definido (rode com flutter test).');
      final font = File('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
      await (FontLoader('MaterialIcons')..addFont(font.readAsBytes().then(ByteData.sublistView))).load();

      final scheme = AppTheme.light().colorScheme;
      final images = <int, ui.Image>{};
      for (final size in iconSizes) {
        images[size] = await renderIcon(size, glyph: scheme.primary, tile: scheme.surfaceContainerLow);
      }
      final ico = await encodeIco(images);
      File('windows/runner/resources/app_icon.ico').writeAsBytesSync(ico);
    });
  });
}

Future<ui.Image> renderIcon(int size, {required Color glyph, required Color tile}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final s = size.toDouble();
  // Margem mínima: em 16 px cada pixel conta.
  final inset = size <= 24 ? 0.0 : s * 0.03;
  final rect = Rect.fromLTWH(inset, inset, s - 2 * inset, s - 2 * inset);
  canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(s * 0.22)), Paint()..color = tile);

  final glyphSize = s * (size <= 24 ? 0.92 : 0.80);
  final painter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(Icons.travel_explore.codePoint),
      style: TextStyle(fontFamily: 'MaterialIcons', fontSize: glyphSize, color: glyph, height: 1),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset((s - painter.width) / 2, (s - painter.height) / 2));
  return recorder.endRecording().toImage(size, size);
}

/// ICO com BMP 32 bits (BGRA) até 128 px e PNG em 256 px: o formato que o
/// Windows, o Explorer e o Inno Setup aceitam em todos os tamanhos.
Future<Uint8List> encodeIco(Map<int, ui.Image> images) async {
  final entries = <(int, Uint8List)>[];
  for (final MapEntry(key: size, value: image) in images.entries) {
    if (size >= 256) {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      entries.add((size, png!.buffer.asUint8List()));
    } else {
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      entries.add((size, _dib(size, rgba!.buffer.asUint8List())));
    }
  }
  final out = BytesBuilder();
  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little)
    ..setUint16(2, 1, Endian.little) // ícone
    ..setUint16(4, entries.length, Endian.little);
  out.add(header.buffer.asUint8List());
  var offset = 6 + 16 * entries.length;
  for (final (size, data) in entries) {
    final dir = ByteData(16)
      ..setUint8(0, size >= 256 ? 0 : size)
      ..setUint8(1, size >= 256 ? 0 : size)
      ..setUint8(2, 0)
      ..setUint8(3, 0)
      ..setUint16(4, 1, Endian.little) // planos
      ..setUint16(6, 32, Endian.little) // bits por pixel
      ..setUint32(8, data.length, Endian.little)
      ..setUint32(12, offset, Endian.little);
    out.add(dir.buffer.asUint8List());
    offset += data.length;
  }
  for (final (_, data) in entries) {
    out.add(data);
  }
  return out.toBytes();
}

/// BITMAPINFOHEADER + pixels BGRA de baixo para cima + máscara AND vazia.
Uint8List _dib(int size, Uint8List rgba) {
  final maskRow = ((size + 31) ~/ 32) * 4;
  final header = ByteData(40)
    ..setUint32(0, 40, Endian.little)
    ..setInt32(4, size, Endian.little)
    ..setInt32(8, size * 2, Endian.little) // cor + máscara
    ..setUint16(12, 1, Endian.little)
    ..setUint16(14, 32, Endian.little)
    ..setUint32(20, size * size * 4 + maskRow * size, Endian.little);
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    final src = (size - 1 - y) * size * 4;
    final dst = y * size * 4;
    for (var x = 0; x < size; x++) {
      final i = src + x * 4, o = dst + x * 4;
      pixels[o] = rgba[i + 2];
      pixels[o + 1] = rgba[i + 1];
      pixels[o + 2] = rgba[i];
      pixels[o + 3] = rgba[i + 3];
    }
  }
  return (BytesBuilder()
        ..add(header.buffer.asUint8List())
        ..add(pixels)
        ..add(Uint8List(maskRow * size)))
      .toBytes();
}
