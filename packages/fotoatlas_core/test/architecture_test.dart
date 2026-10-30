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
  'setFileTime',
  'writeFile',
  'deleteFile',
  'createDirectory',
  // Wrappers de safe_io/ (só a cópia segura e o backup do catálogo usam).
  'moveNoReplace',
  'deleteOwnPart',
  'PartWriter',
  'ensureDirectory',
  // Fase 6: remover pasta vazia (só pasta sem nada dentro, a pedido).
  'removeDirectory',
  'removeEmptyFolder',
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
  // Fase 5 — gravação no destino (ADR 0016): bindings, .part novo (CREATE_NEW),
  // pastas novas e remoção só do próprio .part não publicado.
  ('platform/win32/kernel32.dart', 'writeFile'),
  ('platform/win32/kernel32.dart', 'setFileTime'),
  ('platform/win32/kernel32.dart', 'SetFileTime'),
  ('platform/win32/kernel32.dart', 'createDirectory'),
  ('platform/win32/kernel32.dart', 'deleteFile'),
  ('platform/win32/kernel32.dart', 'DeleteFile'),
  ('safe_io/move_no_replace.dart', 'moveNoReplace'),
  ('safe_io/dest_writer.dart', 'CreateFileW'),
  ('safe_io/dest_writer.dart', 'createFile'),
  ('safe_io/dest_writer.dart', 'writeFile'),
  ('safe_io/dest_writer.dart', 'setFileTime'),
  ('safe_io/dest_writer.dart', 'SetFileTime'),
  ('safe_io/dest_writer.dart', 'createDirectory'),
  ('safe_io/dest_writer.dart', 'deleteFile'),
  ('safe_io/dest_writer.dart', 'DeleteFile'),
  ('safe_io/dest_writer.dart', '.create('),
  ('safe_io/dest_writer.dart', 'PartWriter'),
  ('safe_io/dest_writer.dart', 'ensureDirectory'),
  ('safe_io/dest_writer.dart', 'deleteOwnPart'),
  // A cópia segura usa só os wrappers acima.
  ('ops/copy_pump.dart', 'PartWriter'),
  ('ops/copy_pump.dart', '.create('), // PartWriter.create
  ('ops/copy_service.dart', 'moveNoReplace'),
  ('ops/copy_service.dart', 'deleteOwnPart'),
  ('ops/copy_service.dart', 'ensureDirectory'),
  // Fase 6 — reorganização no mesmo disco (ADR 0017): renomear sem substituir
  // nem copiar, pastas novas e remoção de pasta vazia conferida.
  ('ops/reorg_service.dart', 'moveNoReplace'),
  ('ops/reorg_service.dart', 'ensureDirectory'),
  ('ops/reorg_service.dart', 'removeEmptyFolder'),
  ('platform/win32/kernel32.dart', 'removeDirectory'),
  ('platform/win32/kernel32.dart', 'RemoveDirectory'),
  ('safe_io/empty_dir.dart', 'removeDirectory'),
  ('safe_io/empty_dir.dart', 'RemoveDirectory'),
  ('safe_io/empty_dir.dart', 'removeEmptyFolder'),
  // Backup do catálogo: publicação sem sobrescrever na pasta do catálogo.
  ('catalog/catalog_backup.dart', 'moveNoReplace'),
  // Backup do catálogo: pasta backups/ e rotação dos próprios backups (nunca arquivos de usuário).
  ('catalog/catalog_backup.dart', 'createSync'),
  ('catalog/catalog_backup.dart', 'deleteSync'),
  // Fase 4: só a pasta de cache (%LOCALAPPDATA%\FotoAtlas\thumbs), nunca arquivos de usuário.
  // Leituras parciais do celular (_leitura/): cria a pasta e apaga as cópias depois de ler.
  ('metadata/metadata_service.dart', 'createSync'),
  ('metadata/metadata_service.dart', 'deleteSync'),
  // Miniaturas: pasta, arquivo temporário novo, publicação por renomear e limpeza do temporário.
  ('thumbs/thumbnail_service.dart', 'createSync'),
  ('thumbs/thumbnail_service.dart', 'writeAsBytes'),
  ('thumbs/thumbnail_service.dart', 'renameSync'),
  ('thumbs/thumbnail_service.dart', 'deleteSync'),
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

  test('o destino só recebe arquivos novos e só o próprio .part é apagado', () {
    final src = File(p.join('lib', 'src', 'safe_io', 'dest_writer.dart')).readAsStringSync();
    final calls = RegExp(r'createFile\(([\s\S]*?)\),\s*\);').allMatches(src).toList();
    expect(calls, hasLength(1), reason: 'uma única abertura para escrita');
    final args = calls.single.group(1)!;
    expect(args, contains('createNew'));
    for (final forbidden in ['createAlways', 'openAlways', 'truncateExisting', 'openExisting']) {
      expect(args, isNot(contains(forbidden)));
    }
    // Toda escrita e toda remoção passam pela checagem de caminho .part em .fotoatlas-tmp.
    final create = RegExp(r'static PartWriter create\([\s\S]*?\n  \}').firstMatch(src)!.group(0)!;
    expect(create, contains('isOwnPartPath(path)'));
    final delete = RegExp(r'bool deleteOwnPart\([\s\S]*?\n\}').firstMatch(src)!.group(0)!;
    expect(delete.indexOf('isOwnPartPath(path)'), lessThan(delete.indexOf('deleteFile(')));
    expect(src.split('deleteFile(').length - 1, 1, reason: 'DeleteFileW só em deleteOwnPart');
  });

  test('pasta só é removida vazia, conferida antes, e a reorganização nunca copia entre discos', () {
    final src = File(p.join('lib', 'src', 'safe_io', 'empty_dir.dart')).readAsStringSync();
    expect(src.split('removeDirectory(').length - 1, 1, reason: 'RemoveDirectoryW só em removeEmptyFolder');
    final remove = RegExp(r'bool removeEmptyFolder\([\s\S]*?\n\}').firstMatch(src)!.group(0)!;
    expect(remove.indexOf('listDirectory(dirPath).isNotEmpty'), lessThan(remove.indexOf('removeDirectory(')));
    expect(remove, contains('fileAttributeReparsePoint'));
    // MoveFileExW só com WRITE_THROUGH: sem COPY_ALLOWED (0x2) o Windows recusa
    // mover para outro disco, e sem REPLACE_EXISTING (0x1) nunca sobrescreve.
    final move = File(p.join('lib', 'src', 'safe_io', 'move_no_replace.dart')).readAsStringSync();
    expect(RegExp(r'moveFileEx\(([\s\S]*?)\);').firstMatch(move)!.group(1), contains('movefileWriteThrough'));
    expect(move, isNot(contains('CopyAllowed')));
    final k = File(p.join('lib', 'src', 'platform', 'win32', 'kernel32.dart')).readAsStringSync();
    expect(RegExp(r'const int movefileWriteThrough = (0x\w+);').firstMatch(k)!.group(1), '0x8');
    // O serviço de reorganização não apaga arquivo nenhum.
    final reorg = File(p.join('lib', 'src', 'ops', 'reorg_service.dart')).readAsStringSync();
    for (final api in ['deleteOwnPart', 'deleteFile', 'DeleteFile', 'deleteSync', '.delete(']) {
      expect(reorg, isNot(contains(api)));
    }
  });

  test('a verificação de integridade só lê: nenhuma API de gravação nem de cópia', () {
    final dir = Directory(p.join('lib', 'src', 'integrity'));
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.dart')).toList();
    expect(files, isNotEmpty);
    const copyApis = ['copyToPart', 'PumpRequest', 'CopyService', 'safe_io/dest_writer', 'safe_io/move_no_replace'];
    for (final f in files) {
      final src = f.readAsStringSync();
      for (final api in [..._writeApis, ...copyApis, 'safe_io/empty_dir']) {
        expect(src, isNot(contains(api)), reason: '${p.basename(f.path)} usa $api');
      }
    }
    // Os arquivos são lidos só pelo leitor da conferência (GENERIC_READ),
    // sem exigir tamanho e data do catálogo (para observar a mudança).
    final engine = File(p.join(dir.path, 'integrity_engine.dart')).readAsStringSync();
    expect(engine, contains("import '../hash/hash_engine.dart'"));
    expect(engine, contains('observeOnly: true'));
  });

  test('o core não depende de Flutter', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('flutter')));
  });

  test('nenhum teste abre o core com acesso aos celulares reais', () {
    // Com o helper e sem simulados, o core listaria um celular plugado na
    // máquina de quem roda os testes (CLAUDE.md: testes nunca tocam aparelhos reais).
    final offenders = <String>[];
    for (final dir in ['test', '../../app/test']) {
      for (final file in Directory(dir).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart') || p.basename(file.path) == 'architecture_test.dart') continue;
        final text = file.readAsStringSync();
        for (final call in RegExp(r'FotoAtlasCore\.open\(').allMatches(text)) {
          var depth = 0;
          var end = call.end - 1;
          for (; end < text.length; end++) {
            if (text[end] == '(') depth++;
            if (text[end] == ')' && --depth == 0) break;
          }
          final args = text.substring(call.end, end);
          final safe = ['useHelper: false', 'fakeDevicesDir:', 'devices:', 'volumes:'].any(args.contains);
          if (!safe) offenders.add('${file.path}:${'\n'.allMatches(text.substring(0, call.start)).length + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
