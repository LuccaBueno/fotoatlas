import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Garantia de segurança (`docs/arquitetura.md` §6): só módulos autorizados
/// gravam, movem ou apagam no disco. Qualquer uso novo destas APIs exige
/// revisão e uma entrada explícita na lista abaixo.
const _writeApis = [
  'writeAsBytes',
  'writeAsString',
  'openWrite',
  '.rename(',
  'renameSync',
  '.delete(',
  'deleteSync',
  '.copy(',
  'copySync',
  '.create(',
  'createSync',
  'FileMode.write',
  'FileMode.append',
  'MoveFileEx',
  'DeleteFile',
  'CreateFileW',
  'RemoveDirectory',
  'SetFileAttributes',
  'SetFileTime',
];

/// (arquivo relativo a lib/src, API) permitidos, com o motivo.
const _allowed = {
  // Cria a pasta do catálogo (%APPDATA%\FotoAtlas ou FOTOATLAS_HOME).
  ('catalog/catalog.dart', 'createSync'),
  ('fotoatlas_core_base.dart', 'createSync'),
  // Arquivo de trava do catálogo (catalog.lock), na pasta do catálogo.
  ('util/instance_lock.dart', 'FileMode.append'),
};

void main() {
  test('nenhum módulo fora da lista grava, move ou apaga arquivos', () {
    final root = Directory(p.join('lib', 'src'));
    final violations = <String>[];
    for (final file in root.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') || file.path.endsWith('.g.dart')) continue;
      final rel = p.relative(file.path, from: root.path).replaceAll(r'\', '/');
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.startsWith('//')) continue;
        for (final api in _writeApis) {
          if (line.contains(api) && !_allowed.contains((rel, api))) {
            violations.add('$rel:${i + 1}: $api');
          }
        }
      }
    }
    expect(violations, isEmpty, reason: 'APIs de escrita fora dos módulos autorizados');
  });

  test('o core não depende de Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter')));
  });
}
