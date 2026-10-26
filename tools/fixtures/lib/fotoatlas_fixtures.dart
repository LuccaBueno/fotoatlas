/// Gerador determinístico de árvores sintéticas para testes do FotoAtlas.
///
/// Nunca usa dados reais: nomes imitam padrões de celulares/câmeras e o
/// conteúdo é aleatório a partir de uma semente. Só grava em pastas novas
/// dentro do temp do sistema ou em `tools/fixtures/out|generated`.
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Resumo do que foi gerado (para conferência nos testes).
class FixtureManifest {
  FixtureManifest(this.root);
  final String root;
  int files = 0;
  int dirs = 0;
  int bytes = 0;

  /// Caminhos relativos (com `/`) de todos os arquivos gerados.
  final List<String> relPaths = [];

  /// Caminho relativo de um arquivo cujo caminho absoluto passa de 260 caracteres.
  String? longPathFile;

  /// Pares de arquivos com conteúdo idêntico e nomes diferentes.
  final List<(String, String)> identicalPairs = [];
}

class FixtureOptions {
  const FixtureOptions({
    this.files = 1000,
    this.seed = 1,
    this.maxFileBytes = 4096,
    this.includeLongPath = true,
    this.includeUnicode = true,
    this.duplicateEvery = 50,
  });

  final int files;
  final int seed;
  final int maxFileBytes;
  final bool includeLongPath;
  final bool includeUnicode;

  /// A cada N arquivos, gera uma cópia idêntica com outro nome (0 = nunca).
  final int duplicateEvery;
}

/// Recusa gravar fora de áreas permitidas (regra de segurança do CLAUDE.md).
void assertAllowedOutput(String outDir) {
  final target = p.canonicalize(outDir);
  final temp = p.canonicalize(Directory.systemTemp.path);
  if (p.isWithin(temp, target)) return;
  final parts = p.split(target).map((s) => s.toLowerCase()).toList();
  for (var i = 0; i + 2 < parts.length; i++) {
    if (parts[i] == 'tools' && parts[i + 1] == 'fixtures' && (parts[i + 2] == 'out' || parts[i + 2] == 'generated')) {
      return;
    }
  }
  throw StateError('Fixtures só podem ser gerados no temp do sistema ou em tools/fixtures/out: $target');
}

const _folders = [
  'DCIM/Camera',
  'DCIM/Screenshots',
  'Pictures/WhatsApp/WhatsApp Images',
  'Pictures/WhatsApp/WhatsApp Video',
  'Backup Antigo/Fotos',
  'Backup Antigo/Fotos/Viagem',
  // {ano} e {mes} são trocados pela data do arquivo (centenas de pastas).
  'Fotos/{ano}/{ano}-{mes}',
  'Fotos/2019/Aniversário',
  'Backup HD/{ano}/{mes}',
  'Câmera/DSC',
  'Vídeos',
  'Diversos/a/b/c/d/e/f/g',
];

const _unicodeFolders = ['Férias São João', '日本旅行', 'Ação & Reação (cópia)'];

/// Gera a árvore em [outDir] (precisa ser nova ou vazia).
FixtureManifest generateTree(String outDir, [FixtureOptions options = const FixtureOptions()]) {
  assertAllowedOutput(outDir);
  final root = Directory(outDir);
  if (root.existsSync() && root.listSync().isNotEmpty) {
    throw StateError('A pasta de saída precisa estar vazia: $outDir');
  }
  root.createSync(recursive: true);
  final manifest = FixtureManifest(root.path);
  final random = Random(options.seed);
  final folders = [..._folders, if (options.includeUnicode) ..._unicodeFolders];
  final createdDirs = <String>{};
  final usedPaths = <String>{};
  final base = DateTime.utc(2015, 1, 1);

  void ensureDir(String rel) {
    var acc = '';
    for (final part in rel.split('/')) {
      acc = acc.isEmpty ? part : '$acc/$part';
      if (createdDirs.add(acc)) manifest.dirs++;
    }
    Directory(p.join(root.path, rel)).createSync(recursive: true);
  }

  void writeFile(String rel, Uint8List data, DateTime mtime) {
    final file = File(p.joinAll([root.path, ...rel.split('/')]));
    file.writeAsBytesSync(data, flush: false);
    file.setLastModifiedSync(mtime);
    manifest.files++;
    manifest.bytes += data.length;
    manifest.relPaths.add(rel);
  }

  var produced = 0;
  var counter = 0;
  while (produced < options.files) {
    final when = base.add(Duration(seconds: random.nextInt(10 * 365 * 24 * 3600)));
    final folder = folders[random.nextInt(folders.length)]
        .replaceAll('{ano}', '${when.year}')
        .replaceAll('{mes}', _two(when.month));
    final name = _nameFor(folder, when, counter++, random);
    final rel = '$folder/$name';
    if (!usedPaths.add(rel.toLowerCase())) continue;
    ensureDir(folder);
    final size = random.nextInt(20) == 0 ? 0 : random.nextInt(options.maxFileBytes) + 1;
    final data = Uint8List(size);
    for (var i = 0; i < size; i++) {
      data[i] = random.nextInt(256);
    }
    writeFile(rel, data, when);
    produced++;

    if (options.duplicateEvery > 0 && produced % options.duplicateEvery == 0 && produced < options.files && size > 0) {
      final dupFolder = folders[random.nextInt(folders.length)]
          .replaceAll('{ano}', '${when.year}')
          .replaceAll('{mes}', _two(when.month));
      final dupRel = '$dupFolder/copia_${counter++}_$name';
      if (usedPaths.add(dupRel.toLowerCase())) {
        ensureDir(dupFolder);
        writeFile(dupRel, data, when.add(const Duration(days: 30)));
        manifest.identicalPairs.add((rel, dupRel));
        produced++;
      }
    }
  }

  if (options.includeLongPath) {
    // Caminho absoluto > 260 caracteres (testa o prefixo \\?\).
    final segments = <String>[];
    var length = root.path.length;
    var i = 0;
    while (length < 300) {
      final seg = 'pasta_profunda_${i++}_${'x' * 20}';
      segments.add(seg);
      length += seg.length + 1;
    }
    final relDir = segments.join('/');
    ensureDir(relDir);
    final rel = '$relDir/IMG_20190312_101010.jpg';
    writeFile(rel, Uint8List.fromList(List.generate(128, (i) => i)), DateTime.utc(2019, 3, 12, 10, 10, 10));
    manifest.longPathFile = rel;
  }
  return manifest;
}

String _two(int v) => v.toString().padLeft(2, '0');

String _nameFor(String folder, DateTime t, int counter, Random random) {
  final date = '${t.year}${_two(t.month)}${_two(t.day)}';
  final time = '${_two(t.hour)}${_two(t.minute)}${_two(t.second)}';
  final wa = (counter % 10000).toString().padLeft(4, '0');
  if (folder.contains('WhatsApp Images')) return 'IMG-$date-WA$wa.jpg';
  if (folder.contains('WhatsApp Video')) return 'VID-$date-WA$wa.mp4';
  if (folder.contains('Screenshots')) {
    return 'Screenshot_$date-$time.png';
  }
  if (folder.contains('DSC')) {
    // Nomes repetidos entre pastas, com conteúdo diferente.
    return 'DSC${(counter % 500).toString().padLeft(4, '0')}.JPG';
  }
  if (folder.contains('Vídeos')) {
    return 'VID_${date}_$time.mp4';
  }
  return switch (random.nextInt(6)) {
    0 => 'PXL_${date}_$time${random.nextInt(1000).toString().padLeft(3, '0')}.jpg',
    1 => 'IMG_${date}_$time.heic',
    2 => 'IMG_${(counter % 9999).toString().padLeft(4, '0')}.JPG',
    3 => 'IMG_${date}_$time.dng',
    4 => 'documento_$counter.pdf',
    _ => 'IMG_${date}_${time}_$counter.jpg',
  };
}
