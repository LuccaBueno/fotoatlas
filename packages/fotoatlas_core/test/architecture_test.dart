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
  'moveFileEx',
  'DeleteFile',
  'CreateFileW',
  'createFile',
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
  // Bindings FFI (só declaração; o uso fica restrito a safe_io/).
  ('platform/win32/kernel32.dart', 'CreateFileW'),
  ('platform/win32/kernel32.dart', 'createFile'),
  ('platform/win32/kernel32.dart', 'MoveFileEx'),
  ('platform/win32/kernel32.dart', 'moveFileEx'),
  // Única forma de abrir arquivo de usuário: somente leitura (flags conferidas abaixo).
  ('safe_io/source_reader.dart', 'CreateFileW'),
  ('safe_io/source_reader.dart', 'createFile'),
  // Publicação sem sobrescrever (MoveFileExW sem REPLACE_EXISTING).
  ('safe_io/move_no_replace.dart', 'MoveFileEx'),
  ('safe_io/move_no_replace.dart', 'moveFileEx'),
  // Backup do catálogo: pasta backups/ e rotação dos próprios backups (nunca arquivos de usuário).
  ('catalog/catalog_backup.dart', 'createSync'),
  ('catalog/catalog_backup.dart', 'deleteSync'),
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

  test('a única abertura de arquivo de usuário é somente leitura e nunca cria', () {
    final src = File(p.join('lib', 'src', 'safe_io', 'source_reader.dart')).readAsStringSync();
    final call = RegExp(r'createFile\(([\s\S]*?)\),\s*\);').firstMatch(src);
    expect(call, isNotNull, reason: 'chamada a createFile não encontrada');
    final args = call!.group(1)!;
    expect(args, contains('genericRead'));
    expect(args, contains('openExisting'));
    expect(args, contains('fileFlagOpenNoRecall'));
    for (final forbidden in ['genericWrite', 'createNew', 'createAlways', 'openAlways', 'truncateExisting']) {
      expect(args, isNot(contains(forbidden)));
    }
    // moveNoReplace nunca pede para substituir.
    final move = File(p.join('lib', 'src', 'safe_io', 'move_no_replace.dart')).readAsStringSync();
    expect(move, isNot(contains('ReplaceExisting')));
    expect(move, isNot(contains('0x1')));
  });

  test('o core não depende de Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter')));
  });
}
