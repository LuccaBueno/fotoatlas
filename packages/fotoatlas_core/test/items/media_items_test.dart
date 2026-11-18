import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' show Variable;
import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);
String sha(List<int> b) => sha256.convert(b).toString();

/// Um "HD" com RAW+JPEG, Live Photos (pelo nome e pelo identificador da
/// Apple), um vídeo comum com o mesmo nome de uma foto e arquivos sozinhos.
class ItemsScenario {
  ItemsScenario(this.env, this.hd, this.hd2, this.dstId, this.dst);
  final TestEnv env;
  final String hd;
  final String hd2;
  final String dstId;
  final Directory dst;

  FotoAtlasCore get core => env.core;

  static Future<ItemsScenario> create() async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    env
      ..write('Fotos/DCIM/IMG_0001.JPG', bytes(1, 3000))
      ..write('Fotos/DCIM/IMG_0001.CR2', bytes(2, 9000))
      ..write('Fotos/DCIM/IMG_0002.HEIC', bytes(3, 2000))
      ..write('Fotos/DCIM/IMG_0002.MOV', bytes(4, 4000))
      ..write('Fotos/DCIM/IMG_0003.HEIC', bytes(5, 2100))
      ..write('Fotos/DCIM/IMG_E0003.MOV', bytes(6, 4100))
      ..write('Fotos/DCIM/IMG_0004.JPG', bytes(7, 2200))
      ..write('Fotos/DCIM/IMG_0004.MP4', bytes(8, 8000))
      ..write('Fotos/DCIM/IMG_0005.JPG', bytes(9, 2300))
      // Mesmo nome, outra pasta: não é par.
      ..write('Fotos/Outra/IMG_0005.CR2', bytes(10, 9100));
    final hd = await env.addFolder('Fotos', name: 'HD');
    final vol2 = env.addVolume('HD2');
    final dstVol = env.addVolume('Backup', mount: r'G:\');
    // O JPEG da 0001 já tem cópia no HD2; o RAW não.
    env.write('Copia/IMG_0001.JPG', bytes(1, 3000), volume: vol2);
    final hd2 = await env.addFolder('Copia', name: 'HD2', volume: vol2);
    final dst = await env.addFolder('Backup', name: 'Backup', volume: dstVol);
    for (final s in [hd, hd2, dst]) {
      await env.scan(s);
    }
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    final s = ItemsScenario(env, hd, hd2, dst, Directory(p.join(dstVol.path, 'Backup')));
    // O que o ExifTool/ffprobe leriam: duração dos vídeos e o identificador
    // comum da Live Photo de nomes diferentes.
    await s.meta('IMG_0002.MOV', durationMs: 2500);
    await s.meta('IMG_0004.MP4', durationMs: 60000);
    await s.meta('IMG_0003.HEIC', cid: 'A1B2-C3');
    await s.meta('IMG_E0003.MOV', cid: 'A1B2-C3', durationMs: 2700);
    return s;
  }

  Future<int> id(String name, {String? source}) async =>
      (await env.db
              .customSelect(
                'SELECT content_id FROM file_instances WHERE name = ? AND source_id = ?',
                variables: [Variable.withString(name), Variable.withString(source ?? hd)],
              )
              .getSingle())
          .read<int>('content_id');

  Future<void> meta(String name, {int? durationMs, String? cid}) async {
    await env.db.customStatement(
      'INSERT INTO media_metadata (content_id, duration_ms, content_identifier, meta_status) VALUES (?, ?, ?, ?) '
      "ON CONFLICT(content_id) DO UPDATE SET duration_ms = excluded.duration_ms, "
      "content_identifier = excluded.content_identifier, meta_status = 'full'",
      [await id(name), durationMs, cid, 'full'],
    );
  }

  /// Nomes dos arquivos de cada item agrupado (ordenados).
  Future<Set<String>> groups() async {
    final out = <String>{};
    for (final item in await core.items.all()) {
      final names = <String>[];
      for (final m in item.members) {
        final r = await env.db
            .customSelect(
              'SELECT name FROM file_instances WHERE content_id = ? ORDER BY id LIMIT 1',
              variables: [Variable.withInt(m.contentId)],
            )
            .getSingle();
        names.add('${r.read<String>('name')}:${m.role}');
      }
      out.add('${item.kind.sql} ${(names..sort()).join(' ')}');
    }
    return out;
  }
}

void main() {
  test('detecta RAW+JPEG e Live Photos (nome + vídeo curto, ou identificador), só no catálogo', () async {
    final s = await ItemsScenario.create();
    final before = {
      for (final f in Directory(p.join(s.env.volumeDir.path, 'Fotos')).listSync(recursive: true).whereType<File>())
        f.path: sha(f.readAsBytesSync()),
    };
    expect(await s.core.items.detect(), 2, reason: 'as Live Photos dependiam da duração e do identificador');
    expect(await s.groups(), {
      'raw_jpeg IMG_0001.CR2:raw IMG_0001.JPG:photo',
      'live_photo IMG_0002.HEIC:photo IMG_0002.MOV:video',
      'live_photo IMG_0003.HEIC:photo IMG_E0003.MOV:video',
    });
    // Vídeo de 1 minuto com o mesmo nome e o RAW de outra pasta ficam sozinhos.
    expect(await s.core.items.detect(), 0, reason: 'rodar de novo não duplica');
    // Nenhum arquivo foi tocado.
    expect({
      for (final f in Directory(p.join(s.env.volumeDir.path, 'Fotos')).listSync(recursive: true).whereType<File>())
        f.path: sha(f.readAsBytesSync()),
    }, before);
  });

  test('RAW+JPEG que depois ganha o vídeo da Live Photo vira um item só', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    env
      ..write('F/IMG_9.JPG', bytes(1, 1000))
      ..write('F/IMG_9.DNG', bytes(2, 5000))
      ..write('F/IMG_9.MOV', bytes(3, 3000));
    final hd = await env.addFolder('F');
    await env.scan(hd);
    await env.hashAll();
    await env.core.settleDates();
    expect((await env.core.items.all()).single.kind, MediaItemKind.rawJpeg);
    final mov =
        (await env.db.customSelect("SELECT content_id FROM file_instances WHERE name = 'IMG_9.MOV'").getSingle())
            .read<int>('content_id');
    await env.db.customStatement(
      "INSERT INTO media_metadata (content_id, duration_ms, meta_status) VALUES (?, 2000, 'full') "
      "ON CONFLICT(content_id) DO UPDATE SET duration_ms = 2000, meta_status = 'full'",
      [mov],
    );
    expect(await env.core.items.detect(), 1);
    final item = (await env.core.items.all()).single;
    expect(item.kind, MediaItemKind.livePhoto);
    expect(item.members.map((m) => m.role).toSet(), {'photo', 'raw', 'video'});
  });

  test('Biblioteca: um item só, com o selo e a pior situação de backup; filtro por tipo mostra cada arquivo', () async {
    final s = await ItemsScenario.create();
    await s.core.items.detect();
    final jpg = await s.id('IMG_0001.JPG'), raw = await s.id('IMG_0001.CR2');
    final heic = await s.id('IMG_0002.HEIC'), mov = await s.id('IMG_0002.MOV');
    final index = await s.core.library.index(LibraryFilter.empty);
    expect(index.ids, contains(jpg));
    expect(index.ids, isNot(contains(raw)));
    expect(index.ids, contains(heic));
    expect(index.ids, isNot(contains(mov)));
    expect(await s.core.library.count(LibraryFilter.empty), index.length);
    final item = (await s.core.library.items([jpg])).single;
    expect(item.groupKind, MediaItemKind.rawJpeg);
    expect(item.groupFiles, 2);
    // O JPEG tem cópia no HD2, o RAW não: o item mostra "só 1 cópia".
    expect(item.backup, BackupState.single);
    // Filtro por arquivo: o RAW aparece sozinho.
    final raws = await s.core.library.index(
      const LibraryFilter([
        FilterCondition(FilterKind.types, values: ['raw']),
      ]),
    );
    expect(raws.ids, contains(raw));
    // Detalhes listam os arquivos do item, de qualquer um deles.
    final detail = (await s.core.library.detail(raw))!;
    expect(detail.group!.primaryContentId, jpg);
    expect(detail.group!.files.map((f) => (f.$2, f.$3)), [('photo', 'IMG_0001.JPG'), ('raw', 'IMG_0001.CR2')]);
  });

  test('desagrupar não volta sozinho; agrupar à mão; a Biblioteca acompanha', () async {
    final s = await ItemsScenario.create();
    await s.core.items.detect();
    final jpg = await s.id('IMG_0001.JPG'), raw = await s.id('IMG_0001.CR2');
    final changes = <void>[];
    final sub = s.core.library.changes.listen(changes.add);
    addTearDown(sub.cancel);
    final item = (await s.core.items.itemsFor([jpg])).single;
    await s.core.items.split(item.id);
    await pumpEventQueue();
    expect(changes, isNotEmpty, reason: 'a Biblioteca recarrega');
    expect((await s.core.library.index(LibraryFilter.empty)).ids, containsAll([jpg, raw]));
    expect(await s.core.items.detect(), 0, reason: 'o usuário desagrupou: o grupo não volta');
    expect(await s.core.items.itemsFor([jpg]), isEmpty);

    // À mão: JPEG + o RAW de outra pasta.
    final other = await s.id('IMG_0005.CR2');
    final id = await s.core.items.group([other, jpg]);
    final manual = (await s.core.items.itemsFor([jpg])).single;
    expect(manual.id, id);
    expect(manual.kind, MediaItemKind.manual);
    expect(manual.primaryContentId, jpg, reason: 'a foto é a que aparece, não o RAW');
    expect(() => s.core.items.group([jpg]), throwsArgumentError);
  });

  test('cópia: escolher a foto leva o RAW junto (mesma pasta, mesmo sufixo) e a prévia mostra', () async {
    final s = await ItemsScenario.create();
    await s.core.items.detect();
    final jpg = await s.id('IMG_0001.JPG'), heic = await s.id('IMG_0002.HEIC');
    // Outro arquivo com o nome do JPEG já no destino (fora do catálogo).
    final other = File(p.join(s.dst.path, 'fotos', 'IMG_0001.JPG'))
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(bytes(99, 100));
    final preview = await s.core.copies.preview(
      CopyRequest(contentIds: [jpg, heic], destSourceId: s.dstId, destFolder: 'fotos', template: ''),
    );
    expect(
      {for (final i in preview.items) i.srcRelPath: i.dstRelPath},
      {
        'DCIM/IMG_0001.JPG': 'fotos/IMG_0001_1.JPG',
        'DCIM/IMG_0001.CR2': 'fotos/IMG_0001_1.CR2',
        'DCIM/IMG_0002.HEIC': 'fotos/IMG_0002.HEIC',
        'DCIM/IMG_0002.MOV': 'fotos/IMG_0002.MOV',
      },
    );
    expect(preview.grouped, 2);
    expect(preview.addedForGroup, 2);
    expect(preview.items.singleWhere((i) => i.srcRelPath.endsWith('.CR2')).groupedWith, 'IMG_0001.JPG');
    expect(preview.items.singleWhere((i) => i.srcRelPath.endsWith('.MOV')).groupedWith, 'IMG_0002.HEIC');

    // Cada arquivo continua passando pela cópia segura e pela conferência.
    final op = await s.core.copies.start(preview);
    await s.core.copies.waitIdle();
    expect((await s.core.copies.view(op))!.status, OpStatus.completed);
    expect(sha(File(p.join(s.dst.path, 'fotos', 'IMG_0001_1.CR2')).readAsBytesSync()), sha(bytes(2, 9000)));
    expect(sha(File(p.join(s.dst.path, 'fotos', 'IMG_0002.MOV')).readAsBytesSync()), sha(bytes(4, 4000)));
    expect(sha(other.readAsBytesSync()), sha(bytes(99, 100)), reason: 'o arquivo que já estava lá ficou intacto');
  });

  test('cópia: só o que falta do grupo; restaurar e desagrupado levam só o arquivo', () async {
    final s = await ItemsScenario.create();
    await s.core.items.detect();
    final jpg = await s.id('IMG_0001.JPG');
    // O HD2 já tem o JPEG: copiar o item para o HD2 leva só o RAW.
    final toHd2 = await s.core.copies.preview(CopyRequest(contentIds: [jpg], destSourceId: s.hd2, template: ''));
    expect(toHd2.alreadyThere, 1);
    expect(toHd2.items.map((i) => i.srcRelPath), ['DCIM/IMG_0001.CR2']);
    expect(toHd2.items.single.addedForGroup, isTrue);

    final dst = s.dstId;
    final single = await s.core.copies.preview(
      CopyRequest(contentIds: [jpg], destSourceId: dst, template: '', keepGroups: false),
    );
    expect(single.items.map((i) => i.srcRelPath), ['DCIM/IMG_0001.JPG']);
    await s.core.items.split((await s.core.items.itemsFor([jpg])).single.id);
    final split = await s.core.copies.preview(CopyRequest(contentIds: [jpg], destSourceId: dst, template: ''));
    expect(split.items.map((i) => i.srcRelPath), ['DCIM/IMG_0001.JPG']);
    expect(split.grouped, 0);
  });

  test('reorganizar: o RAW segue a foto (mesma pasta, mesmo nome final) e a prévia mostra', () async {
    final env = await TestEnv.open(tools: ExternalTools.none);
    env
      ..write('Fotos/Bagunca/IMG_20240713_140300.JPG', bytes(1, 3000))
      ..write('Fotos/Bagunca/IMG_20240713_140300.CR2', bytes(2, 9000))
      ..write('Fotos/Bagunca/IMG_20240713_140300.xmp', bytes(3, 100))
      // Outra foto com o mesmo nome já no lugar: a foto ganha _1, e o RAW também.
      ..write('Fotos/2024/2024-07/IMG_20240713_140300.JPG', bytes(4, 3100));
    final hd = await env.addFolder('Fotos', name: 'HD');
    await env.scan(hd);
    await env.hashAll();
    await env.core.metadata.start();
    await env.core.settleDates();
    expect((await env.core.items.all()).single.kind, MediaItemKind.rawJpeg);
    final preview = await env.core.reorg.preview(ReorgRequest(sourceId: hd, template: '{ano}/{ano}-{mes}'));
    expect(
      {for (final m in preview.moves) m.srcRelPath: m.dstRelPath},
      {
        'Bagunca/IMG_20240713_140300.JPG': '2024/2024-07/IMG_20240713_140300_1.JPG',
        'Bagunca/IMG_20240713_140300.CR2': '2024/2024-07/IMG_20240713_140300_1.CR2',
        'Bagunca/IMG_20240713_140300.xmp': '2024/2024-07/IMG_20240713_140300_1.xmp',
      },
    );
    expect(preview.grouped, 1);
    expect(preview.moves.singleWhere((m) => m.srcName.endsWith('.CR2')).groupOf, 'Bagunca/IMG_20240713_140300.JPG');
    final id = await env.core.reorg.start(preview);
    await env.core.reorg.waitIdle();
    expect((await env.core.copies.view(id))!.status, OpStatus.completed);
    final root = p.join(env.volumeDir.path, 'Fotos', '2024', '2024-07');
    expect(sha(File(p.join(root, 'IMG_20240713_140300_1.CR2')).readAsBytesSync()), sha(bytes(2, 9000)));
    expect(sha(File(p.join(root, 'IMG_20240713_140300.JPG')).readAsBytesSync()), sha(bytes(4, 3100)));
  });
}
