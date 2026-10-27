import 'package:flutter_test/flutter_test.dart';
import 'package:fotoatlas/l10n/format.dart';
import 'package:fotoatlas/l10n/strings.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

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

  test('contadores de situação com plural e concordância', () {
    expect(backupStateCount(BackupState.single, 1), '1 arquivo com só 1 cópia');
    expect(backupStateCount(BackupState.single, 3), '3 arquivos com só 1 cópia');
    expect(backupStateCount(BackupState.verified, 1), '1 cópia conferida');
    expect(backupStateCount(BackupState.verified, 4), '4 cópias conferidas');
    expect(backupStateCount(BackupState.probable, 2), '2 copiados, falta conferir');
    expect(backupStateCount(BackupState.independent, 1), '1 arquivo com backup em disco independente');
    expect(backupStateCount(BackupState.unknown, 1200), '1.200 arquivos em situação desconhecida');
  });

  test('caminhos com um só separador', () {
    expect(displayPath('HD_antigo', 'pasta2/notas.txt'), 'HD_antigo › pasta2 › notas.txt');
    expect(displayPath('HD_antigo', r'pasta2\sub\notas.txt'), 'HD_antigo › pasta2 › sub › notas.txt');
    expect(displayPath('HD_antigo', ''), 'HD_antigo');
  });
}
