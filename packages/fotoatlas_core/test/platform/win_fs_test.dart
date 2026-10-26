import 'dart:io';

import 'package:fotoatlas_core/src/platform/win32/kernel32.dart';
import 'package:fotoatlas_core/src/platform/win_fs.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/temp.dart';

void main() {
  late Directory temp;
  setUp(() async => temp = await createTestTemp());

  test('lista arquivos e pastas com tamanho, mtime e atributos', () {
    final f = File(p.join(temp.path, 'IMG_0001.jpg'))..writeAsBytesSync(List.filled(1234, 7));
    f.setLastModifiedSync(DateTime.utc(2019, 3, 12, 10, 0, 0));
    Directory(p.join(temp.path, 'sub')).createSync();

    final entries = listDirectory(temp.path);
    expect(entries.map((e) => e.name), unorderedEquals(['IMG_0001.jpg', 'sub']));
    final file = entries.firstWhere((e) => e.name == 'IMG_0001.jpg');
    expect(file.size, 1234);
    expect(file.isDirectory, isFalse);
    // FILETIME de 2019-03-12T10:00:00Z.
    final expected = DateTime.utc(2019, 3, 12, 10).difference(DateTime.utc(1601)).inMicroseconds * 10;
    expect(file.mtime, expected);
    expect(entries.firstWhere((e) => e.name == 'sub').isDirectory, isTrue);
  });

  test('pasta vazia devolve lista vazia; pasta inexistente lança erro', () {
    final empty = Directory(p.join(temp.path, 'vazia'))..createSync();
    expect(listDirectory(empty.path), isEmpty);
    expect(
      () => listDirectory(p.join(temp.path, 'nao_existe')),
      throwsA(isA<Win32Exception>().having((e) => e.code, 'code', errorPathNotFound)),
    );
  });

  test('lista caminhos com mais de 260 caracteres', () {
    var dir = temp.path;
    while (dir.length < 300) {
      dir = p.join(dir, 'nivel_${'y' * 30}');
    }
    Directory(dir).createSync(recursive: true);
    File(p.join(dir, 'foto.jpg')).writeAsBytesSync([1, 2, 3]);
    final entries = listDirectory(dir);
    expect(entries.single.name, 'foto.jpg');
    expect(entries.single.size, 3);
  });

  test('junction aparece como reparse point (o scan não a segue)', () async {
    final target = Directory(p.join(temp.path, 'alvo'))..createSync();
    final link = p.join(temp.path, 'atalho');
    final r = await Process.run('cmd', ['/c', 'mklink', '/J', link, target.path]);
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}');
    final entry = listDirectory(temp.path).firstWhere((e) => e.name == 'atalho');
    expect(entry.isDirectory, isTrue);
    expect(entry.isReparsePoint, isTrue);
    expect(entry.reparseTag, ioReparseTagMountPoint);
  });

  test('caminho estendido', () {
    expect(toExtendedPath(r'C:\Fotos'), r'\\?\C:\Fotos');
    expect(toExtendedPath('C:/Fotos/2019'), r'\\?\C:\Fotos\2019');
    expect(toExtendedPath(r'\\?\Volume{abc}\Fotos'), r'\\?\Volume{abc}\Fotos');
    expect(toExtendedPath(r'\\servidor\share'), r'\\?\UNC\servidor\share');
    expect(joinNative(r'\\?\Volume{abc}\', 'Fotos/2019'), r'\\?\Volume{abc}\Fotos\2019');
    expect(joinNative(r'E:\', ''), 'E:');
  });

  test('raiz e GUID do volume do temp', () {
    final root = volumeRootFor(temp.path);
    expect(p.isWithin(root, temp.path), isTrue);
    expect(volumeGuidForRoot(root), startsWith(r'\\?\Volume{'));
  });
}
