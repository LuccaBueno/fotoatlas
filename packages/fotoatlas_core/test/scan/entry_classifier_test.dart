import 'package:fotoatlas_core/src/platform/win32/kernel32.dart';
import 'package:fotoatlas_core/src/platform/win_fs.dart';
import 'package:fotoatlas_core/src/scan/entry_classifier.dart';
import 'package:test/test.dart';

RawDirEntry entry(String name, {int attributes = 0, int tag = 0}) =>
    RawDirEntry(name: name, attributes: attributes, size: 10, mtime: 1, ctime: 1, reparseTag: tag);

EntryAction classify(RawDirEntry e, {bool root = false}) => classifyEntry(e, atVolumeRoot: root);

void main() {
  const dir = fileAttributeDirectory;
  const reparse = fileAttributeReparsePoint;

  test('arquivo comum e placeholder de nuvem', () {
    expect(classify(entry('a.jpg')), EntryAction.file);
    expect(
      classify(entry('a.jpg', attributes: fileAttributeRecallOnDataAccess | reparse, tag: ioReparseTagCloud)),
      EntryAction.cloudOnlyFile,
    );
    expect(classify(entry('b.jpg', attributes: fileAttributeOffline)), EntryAction.cloudOnlyFile);
    // Arquivo do OneDrive já baixado: reparse de nuvem, mas sem recall → local.
    expect(classify(entry('c.jpg', attributes: reparse, tag: 0x9000101A)), EntryAction.file);
  });

  test('junctions e symlinks não são seguidos; pastas do OneDrive são', () {
    expect(
      classify(entry('j', attributes: dir | reparse, tag: ioReparseTagMountPoint)),
      EntryAction.reparsePointSkipped,
    );
    expect(classify(entry('s', attributes: dir | reparse, tag: ioReparseTagSymlink)), EntryAction.reparsePointSkipped);
    expect(classify(entry('link.jpg', attributes: reparse, tag: ioReparseTagSymlink)), EntryAction.reparsePointSkipped);
    expect(classify(entry('OneDrive', attributes: dir | reparse, tag: ioReparseTagCloud)), EntryAction.directory);
  });

  test('exclusões', () {
    expect(classify(entry(r'$RECYCLE.BIN', attributes: dir)), EntryAction.excludedDirectory);
    expect(classify(entry('.fotoatlas-tmp', attributes: dir)), EntryAction.excludedDirectory);
    expect(classify(entry('Windows', attributes: dir), root: true), EntryAction.excludedDirectory);
    expect(classify(entry('Windows', attributes: dir)), EntryAction.directory);
    expect(classify(entry('AppData', attributes: dir | fileAttributeHidden)), EntryAction.excludedDirectory);
    expect(classify(entry('pagefile.sys'), root: true), EntryAction.ignored);
    expect(classify(entry('pagefile.sys')), EntryAction.file);
  });

  test('extensão', () {
    expect(extensionOf('IMG_1.JPG'), 'jpg');
    expect(extensionOf('foto.tar.gz'), 'gz');
    expect(extensionOf('.oculto'), '');
    expect(extensionOf('semextensao'), '');
    expect(extensionOf('ponto.'), '');
  });
}
