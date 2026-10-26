import '../platform/win32/kernel32.dart';
import '../platform/win_fs.dart';

/// O que fazer com uma entrada de diretório durante o scan.
enum EntryAction {
  /// Arquivo com conteúdo local.
  file,

  /// Placeholder de nuvem (OneDrive etc.): catalogado sem abrir (R9).
  cloudOnlyFile,

  /// Pasta a percorrer.
  directory,

  /// Pasta da lista de exclusão (L10).
  excludedDirectory,

  /// Junction/symlink: não seguimos (evita ciclos e dupla contagem).
  reparsePointSkipped,

  /// Arquivo de sistema ignorado (pagefile etc.).
  ignored,
}

/// Exclusões em qualquer profundidade (comparação sem caixa).
const Set<String> excludedDirNamesAnywhere = {
  r'$recycle.bin',
  'system volume information',
  '.fotoatlas-tmp',
  r'$winreagent',
  r'$windows.~bt',
  r'$windows.~ws',
};

/// Exclusões só na raiz de um volume inteiro.
const Set<String> excludedDirNamesAtVolumeRoot = {
  'windows',
  'program files',
  'program files (x86)',
  'programdata',
  'recovery',
  'perflogs',
  'msocache',
};

const Set<String> ignoredFileNamesAtVolumeRoot = {
  'pagefile.sys',
  'hiberfil.sys',
  'swapfile.sys',
  'dumpstack.log.tmp',
  'dumpstack.log',
};

/// Classifica [entry]. [atVolumeRoot] = a pasta listada é a raiz de um volume.
EntryAction classifyEntry(RawDirEntry entry, {required bool atVolumeRoot}) {
  final lower = entry.name.toLowerCase();
  if (entry.isDirectory) {
    if (entry.isReparsePoint && _isLinkTag(entry.reparseTag)) {
      return EntryAction.reparsePointSkipped;
    }
    if (excludedDirNamesAnywhere.contains(lower)) return EntryAction.excludedDirectory;
    if (atVolumeRoot && excludedDirNamesAtVolumeRoot.contains(lower)) {
      return EntryAction.excludedDirectory;
    }
    // AppData (oculta) dentro de perfis de usuário: enorme e sem fotos pessoais.
    if (lower == 'appdata' && entry.attributes & fileAttributeHidden != 0) {
      return EntryAction.excludedDirectory;
    }
    return EntryAction.directory;
  }
  if (entry.isReparsePoint && _isLinkTag(entry.reparseTag)) {
    return EntryAction.reparsePointSkipped;
  }
  if (atVolumeRoot && ignoredFileNamesAtVolumeRoot.contains(lower)) return EntryAction.ignored;
  if (isCloudOnly(entry.attributes)) return EntryAction.cloudOnlyFile;
  return EntryAction.file;
}

/// Atributos de arquivo "sob demanda": abrir dispararia o download.
bool isCloudOnly(int attributes) =>
    attributes & (fileAttributeRecallOnDataAccess | fileAttributeRecallOnOpen | fileAttributeOffline) != 0;

/// Só junctions/pontos de montagem e symlinks são "links". Pastas do OneDrive
/// também são reparse points (tag de nuvem) e devem ser percorridas.
bool _isLinkTag(int tag) => tag == ioReparseTagMountPoint || tag == ioReparseTagSymlink;

/// Extensão minúscula sem ponto (`''` se não houver ou se o nome começa com ponto).
String extensionOf(String name) {
  final i = name.lastIndexOf('.');
  if (i <= 0 || i == name.length - 1) return '';
  return name.substring(i + 1).toLowerCase();
}
