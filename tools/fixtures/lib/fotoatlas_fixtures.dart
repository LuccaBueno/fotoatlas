/// Gerador determinístico de árvores sintéticas para testes do FotoAtlas.
///
/// Nunca usa dados reais: nomes imitam padrões de celulares/câmeras e o
/// conteúdo é aleatório a partir de uma semente. Só grava em pastas novas
/// dentro do temp do sistema ou em `tools/fixtures/out|generated`.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'media_fixtures.dart';

export 'media_fixtures.dart';

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

/// Resultado de [generatePhoneDemo].
class PhoneDemo {
  const PhoneDemo(this.devicesDir, this.hdDir, this.cameraDir);

  /// Pasta para `FOTOATLAS_FAKE_DEVICES` (um `.json` por celular simulado).
  final String devicesDir;

  /// Pasta que faz o papel do HD de backup (cadastrar como pasta).
  final String hdDir;

  /// Fotos de uma câmera com o relógio 1 h adiantado, tiradas junto com as do
  /// Pixel (Fase 4: linha do tempo, momentos e correção de relógio).
  final String cameraDir;

  /// Arquivo do Pixel simulado: apagar/renomear = desplugar o celular.
  String get pixelJson => p.join(devicesDir, 'pixel.json');
}

/// Celulares simulados (formato de `docs/protocolo-helper.md` §5.3.1) e um HD
/// com parte das fotos já copiadas, com outros nomes.
///
/// Esperado para A = Pixel inteiro × B = HD: faltam 3 (IMG_20240502_120000.jpg,
/// IMG-20240504-WA0001.jpg, Screenshot_20240505-180000.png) · nos dois 3 ·
/// só em B 1 (antiga.jpg). O iPhone aparece "sem autorização" (aviso de
/// "Confiar" e de "Manter originais").
PhoneDemo generatePhoneDemo(String outDir, {bool stableIds = false, Map<String, Object?>? pixelFaults}) {
  assertAllowedOutput(outDir);
  final devices = p.join(outDir, 'celulares');
  final hd = p.join(outDir, 'HD');
  List<int> content(int seed, int size) {
    final r = Random(seed);
    return List.generate(size, (_) => r.nextInt(256));
  }

  void write(String path, List<int> bytes) {
    final f = File(path);
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
  }

  // Fotos com EXIF de verdade (Fase 4: datas, câmera, miniatura embutida),
  // completadas com bytes aleatórios depois do fim da imagem para ter um
  // tamanho realista.
  List<int> photo(ExifSpec spec, int seed, int size) {
    final jpeg = jpegWithExif(spec);
    return [...jpeg, ...content(seed, size - jpeg.length)];
  }

  const pixelCam = ('Google', 'Pixel 9');
  final blobs = <String, List<int>>{
    'c1': photo(
      ExifSpec(dateTimeOriginal: DateTime(2024, 5, 1, 10), make: pixelCam.$1, model: pixelCam.$2, uniqueId: 'c1'),
      11,
      900 * 1024,
    ),
    'c2': photo(
      ExifSpec(
        dateTimeOriginal: DateTime(2024, 5, 2, 12),
        subSecMs: 250,
        make: pixelCam.$1,
        model: pixelCam.$2,
        uniqueId: 'c2',
        color: 1,
      ),
      12,
      1100 * 1024,
    ),
    'c3': mp4WithCreationTime(DateTime.utc(2024, 5, 3, 12), durationMs: 12000, salt: 13),
    // WhatsApp tira o EXIF: só o nome diz o dia.
    'c4': photo(const ExifSpec(uniqueId: 'c4', color: 2, thumbnail: false), 14, 150 * 1024),
    'c5': photo(const ExifSpec(uniqueId: 'c5', color: 3, thumbnail: false), 15, 400 * 1024),
    'c6': photo(
      ExifSpec(dateTimeOriginal: DateTime(2023, 1, 1), make: pixelCam.$1, model: pixelCam.$2, uniqueId: 'c6'),
      16,
      700 * 1024,
    ),
    'c7': photo(
      ExifSpec(
        dateTimeOriginal: DateTime(2024, 6, 1, 9),
        offset: '-03:00',
        make: 'Apple',
        model: 'iPhone 13',
        uniqueId: 'c7',
        color: 1,
      ),
      17,
      500 * 1024,
    ),
    'cx': content(18, 4 * 1024),
  };
  for (final e in blobs.entries) {
    write(p.join(devices, 'conteudo', '${e.key}.bin'), e.value);
  }
  Map<String, Object?> file(String path, String blob, String modified) => {
    'path': path,
    'contentFile': 'conteudo/$blob.bin',
    'modified': modified,
  };
  final pixel = {
    'deviceId': r'\?\usb#vid_18d1&pid_4ee1#simulado0001#{6ac27878-a6fa-4155-ba85-f98f491d4f33}',
    'friendlyName': 'Pixel de Teste',
    'manufacturer': 'Google',
    'model': 'Pixel 9',
    'serial': 'SIMULADO0001',
    'kind': 'android',
    'status': 'ok',
    'stableIds': stableIds,
    'storages': [
      {
        'name': 'Armazenamento interno compartilhado',
        'totalBytes': 128000000000,
        'freeBytes': 40000000000,
        'folders': ['Download', 'Music'],
        'files': [
          file('DCIM/Camera/IMG_20240501_100000.jpg', 'c1', '2024-05-01T13:00:00Z'),
          file('DCIM/Camera/IMG_20240502_120000.jpg', 'c2', '2024-05-02T15:00:00Z'),
          file('DCIM/Camera/VID_20240503_090000.mp4', 'c3', '2024-05-03T12:00:00Z'),
          file('WhatsApp/Media/WhatsApp Images/IMG-20240504-WA0001.jpg', 'c4', '2024-05-04T20:00:00Z'),
          file('Pictures/Screenshots/Screenshot_20240505-180000.png', 'c5', '2024-05-05T21:00:00Z'),
          file('Android/data/com.exemplo.app/cache/temp.bin', 'cx', '2024-05-06T10:00:00Z'),
        ],
      },
      {
        'name': 'Cartão SD',
        'totalBytes': 64000000000,
        'freeBytes': 50000000000,
        'files': [file('DCIM/Camera/IMG_20230101_000000.jpg', 'c6', '2023-01-01T03:00:00Z')],
      },
    ],
    'faults': ?pixelFaults,
  };
  final iphone = {
    'deviceId': r'\?\usb#vid_05ac&pid_12a8#simulado0002#{6ac27878-a6fa-4155-ba85-f98f491d4f33}',
    'friendlyName': 'iPhone de Teste',
    'manufacturer': 'Apple Inc.',
    'model': 'iPhone',
    'serial': 'SIMULADO0002',
    'kind': 'iphone',
    'status': 'unauthorized',
    'storages': [
      {
        'name': 'Internal Storage',
        'files': [file('DCIM/100APPLE/IMG_0001.HEIC', 'c7', '2024-06-01T12:00:00Z')],
      },
    ],
  };
  const json = JsonEncoder.withIndent('  ');
  File(p.join(devices, 'pixel.json')).writeAsStringSync(json.convert(pixel));
  File(p.join(devices, 'iphone.json')).writeAsStringSync(json.convert(iphone));

  write(p.join(hd, 'Backup do celular', '2024', '2024-05', 'foto praia.jpg'), blobs['c1']!);
  write(p.join(hd, 'Backup do celular', '2024', '2024-05', 'video.mp4'), blobs['c3']!);
  write(p.join(hd, 'Backup do celular', '2023', 'ano novo.jpg'), blobs['c6']!);
  write(p.join(hd, 'Backup do celular', '2023', 'antiga.jpg'), blobs['c7']!);
  // Fase 5: um arquivo com o mesmo nome de uma foto que falta, mas com outro
  // conteúdo (uma cópia da foto da praia renomeada). Copiar o que falta para
  // "Backup do celular" por ano e mês mostra o conflito: a foto nova ganha "_1"
  // e este arquivo fica intacto. Não muda a comparação (o conteúdo já está nos dois).
  write(p.join(hd, 'Backup do celular', '2024', '2024-05', 'IMG_20240502_120000.jpg'), blobs['c1']!);
  final camera = p.join(outDir, 'Câmera');
  for (final (name, shown, seed) in [
    ('IMG_0001.JPG', DateTime(2024, 5, 1, 11, 0, 20), 21),
    ('IMG_0002.JPG', DateTime(2024, 5, 1, 11, 5), 22),
    ('IMG_0003.JPG', DateTime(2024, 5, 2, 13, 0, 5), 23),
  ]) {
    write(
      p.join(camera, name),
      photo(
        ExifSpec(
          dateTimeOriginal: shown,
          make: 'Canon',
          model: 'Canon EOS X',
          serial: '0123',
          uniqueId: name,
          color: seed,
        ),
        seed,
        2 * 1024 * 1024,
      ),
    );
  }
  return PhoneDemo(devices, hd, camera);
}

/// "HD bagunçado" sintético para testar a reorganização (Fase 6): fotos
/// espalhadas em pastas sem critério, com a data no EXIF **e** no nome (dá o
/// mesmo resultado com ou sem ExifTool).
///
/// Com o modelo "Por ano e momento" no dispositivo inteiro, o esperado é:
///
///     2024/2024-07-13 14h03/   3 fotos + 1 .xmp (vira o nome do momento, se você o nomear)
///     2024/2024-08-20 09h30/   a foto que já estava lá + IMG_20240820_093000_1.jpg (nome repetido)
///                              + 1 vídeo + 1 foto de "Velhas"
///     2024/2024-12-31 23h30/   2 fotos (o momento atravessa a meia-noite)
///     Sem data confirmada/     foto_escaneada.jpg (sem data confiável)
///
/// Ficam onde estão: "lista de compras.txt" (não é foto) e Thumbs.db (oculto e
/// de sistema, faz "Velhas" não ficar vazia).
void generateReorgDemo(String outDir) {
  assertAllowedOutput(outDir);
  final dir = Directory(outDir);
  if (dir.existsSync() && dir.listSync().isNotEmpty) {
    throw StateError('A pasta de saída precisa estar vazia: $outDir');
  }
  var n = 0;
  File write(String rel, List<int> bytes, {DateTime? mtime}) {
    final f = File(p.join(outDir, rel));
    f.parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    if (mtime != null) f.setLastModifiedSync(mtime);
    return f;
  }

  void photo(String rel, DateTime at) => write(
    rel,
    jpegWithExif(ExifSpec(dateTimeOriginal: at, make: 'Google', model: 'Pixel 7', uniqueId: 'reorg-${n++}', color: n)),
    mtime: at,
  );

  photo('Downloads antigos/IMG_20240713_140300.jpg', DateTime(2024, 7, 13, 14, 3));
  write(
    'Downloads antigos/IMG_20240713_140300.xmp',
    utf8.encode('<x:xmpmeta xmlns:x="adobe:ns:meta/"><!-- edição de demonstração --></x:xmpmeta>\n'),
  );
  photo('Downloads antigos/sub/IMG_20240713_151000.jpg', DateTime(2024, 7, 13, 15, 10));
  photo('Pendrive da tia/IMG_20240713_162000.jpg', DateTime(2024, 7, 13, 16, 20));
  photo('Pendrive da tia/IMG_20240820_093000.jpg', DateTime(2024, 8, 20, 9, 30));
  // 09:45 em São Paulo (12:45 UTC).
  write('Pendrive da tia/VID_20240820_094500.mp4', mp4WithCreationTime(DateTime.utc(2024, 8, 20, 12, 45), salt: 7));
  photo('Pendrive da tia/IMG_20241231_233000.jpg', DateTime(2024, 12, 31, 23, 30));
  photo('Pendrive da tia/IMG_20250101_001500.jpg', DateTime(2025, 1, 1, 0, 15));
  photo('Velhas/IMG_20240820_100000.jpg', DateTime(2024, 8, 20, 10));
  final thumbs = write('Velhas/Thumbs.db', List.filled(64, 0));
  // Outra foto, com o mesmo nome e a mesma hora, já no lugar: a do pendrive ganha _1.
  photo('2024/2024-08-20 09h30/IMG_20240820_093000.jpg', DateTime(2024, 8, 20, 9, 30));
  write(
    'Sem nome/foto_escaneada.jpg',
    jpegWithExif(const ExifSpec(make: 'Scanner', model: 'Demo', uniqueId: 'reorg-scan', color: 3)),
    mtime: DateTime(2019, 3, 3, 3, 3),
  );
  write('Sem nome/lista de compras.txt', utf8.encode('pão, café, leite\n'));
  // Thumbs.db de verdade é oculto e de sistema.
  final attrib = Process.runSync('attrib', ['+h', '+s', thumbs.path]);
  if (attrib.exitCode != 0) throw StateError('Não deu para marcar Thumbs.db como oculto: ${attrib.stderr}');
}
