import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/l10n/format.dart';

void main() {
  test('números com separador de milhar', () {
    expect(formatInt(0), '0');
    expect(formatInt(999), '999');
    expect(formatInt(1234), '1.234');
    expect(formatInt(1234567), '1.234.567');
    expect(formatInt(-1500), '-1.500');
  });

  test('tamanhos com vírgula decimal', () {
    expect(formatBytes(null), '—');
    expect(formatBytes(1), '1 byte');
    expect(formatBytes(512), '512 bytes');
    expect(formatBytes(1536), '1,5 KB');
    expect(formatBytes(5 * 1024 * 1024 * 1024), '5,0 GB');
    expect(formatBytes(500 * 1024 * 1024 * 1024), '500 GB');
  });

  test('plural', () {
    expect(plural(1, 'arquivo', 'arquivos'), '1 arquivo');
    expect(plural(2000, 'arquivo', 'arquivos'), '2.000 arquivos');
  });
}
