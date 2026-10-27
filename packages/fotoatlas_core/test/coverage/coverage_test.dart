import 'package:fotoatlas_core/fotoatlas_core.dart';
import 'package:test/test.dart';

import '../support/test_core.dart';

List<int> bytes(int seed, int length) => List.generate(length, (i) => (i * 13 + seed * 101) & 0xff);

void main() {
  test('3 fontes: só 1 cópia, mesmo disco e discos independentes', () async {
    final env = await TestEnv.open();
    // Fonte 1 e 2 no mesmo HD (disco físico do volume principal); fonte 3 em outro HD.
    final hd2 = env.addVolume('HD2', diskSerial: 'WD-OUTRO-0002');
    env.write('Celular/so_aqui.jpg', bytes(1, 1000));
    env.write('Celular/IMG_0002.jpg', bytes(2, 1001));
    env.write('Celular/IMG_0003.jpg', bytes(3, 1002));
    env.write('Celular/IMG_0004.jpg', bytes(4, 1003));
    // Cópia no mesmo disco, com outro nome.
    env.write('Backup/2020/foto_dois.jpg', bytes(2, 1001));
    // Cópia em outro disco, com outro nome e pasta.
    env.write('fotos antigas/tres.jpg', bytes(3, 1002), volume: hd2);
    // Mesmo nome e tamanho de IMG_0004, conteúdo diferente: NÃO é cópia.
    env.write('fotos antigas/IMG_0004.jpg', bytes(99, 1003), volume: hd2);

    final celular = await env.addFolder('Celular');
    final backup = await env.addFolder('Backup');
    final antigo = await env.addFolder('fotos antigas', volume: hd2);
    for (final id in [celular, backup, antigo]) {
      await env.scan(id);
    }

    // Antes do hash: tamanho único já é "só 1 cópia" (L8); mesmo nome+tamanho é "provável".
    var states = await env.core.coverage.statesForSource(celular);
    expect(states['so_aqui.jpg'], BackupState.single);
    expect(states['IMG_0004.jpg'], BackupState.probable);
    expect(states['IMG_0002.jpg'], BackupState.unknown);

    await env.hashAll();
    states = await env.core.coverage.statesForSource(celular);
    expect(states, {
      'so_aqui.jpg': BackupState.single,
      'IMG_0002.jpg': BackupState.verified,
      'IMG_0003.jpg': BackupState.independent,
      'IMG_0004.jpg': BackupState.single,
    });
    expect((await env.core.coverage.statesForSource(antigo))['IMG_0004.jpg'], BackupState.single);

    final report = await env.core.coverage.report();
    // Conteúdos distintos: so_aqui, IMG_0004 (celular), IMG_0004 (antigo) → 3 com só 1 cópia.
    expect(report.overall.filesIn(BackupState.single), 3);
    expect(report.overall.filesIn(BackupState.verified), 1);
    expect(report.overall.filesIn(BackupState.independent), 1);
    expect(report.overall.filesIn(BackupState.unknown), 0);
    expect(report.pendingFiles, 0);
    expect(report.perSource[celular]!.counts.filesIn(BackupState.single), 2);
    expect(report.perSource[backup]!.counts.filesIn(BackupState.verified), 1);
  });

  test('disco de identidade fraca nunca conta como independente (R1)', () async {
    final env = await TestEnv.open();
    final pendrive = env.addVolume('PEN', diskSerial: null, diskConfidence: 'weak');
    env.write('Fotos/a.jpg', bytes(1, 500));
    env.write('Copia/a.jpg', bytes(1, 500), volume: pendrive);
    final a = await env.addFolder('Fotos');
    final b = await env.addFolder('Copia', volume: pendrive);
    await env.scan(a);
    await env.scan(b);
    await env.hashAll();
    expect((await env.core.coverage.statesForSource(a))['a.jpg'], BackupState.verified);
  });

  test('fontes sobrepostas: o mesmo arquivo físico conta como uma cópia só', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 500));
    final pasta = await env.addFolder('Fotos');
    final inteiro = await env.addFolder('');
    await env.scan(pasta);
    await env.scan(inteiro);
    await env.hashAll();
    expect((await env.core.coverage.statesForSource(pasta))['a.jpg'], BackupState.single);
    expect((await env.core.coverage.statesForSource(inteiro))['Fotos/a.jpg'], BackupState.single);
  });

  test('fonte desconectada continua contando como cópia (regra 9)', () async {
    final env = await TestEnv.open();
    final hd2 = env.addVolume('HD2');
    env.write('Fotos/a.jpg', bytes(1, 500));
    env.write('Backup/a.jpg', bytes(1, 500), volume: hd2);
    final a = await env.addFolder('Fotos');
    final b = await env.addFolder('Backup', volume: hd2);
    await env.scan(a);
    await env.scan(b);
    await env.hashAll();
    env.volumes.volumes = [env.volumes.volumes.first];
    await env.core.sources.refreshConnectivity();
    expect((await env.core.sources.list()).firstWhere((s) => s.id == b).state, SourceState.disconnected);
    expect((await env.core.coverage.statesForSource(a))['a.jpg'], BackupState.independent);
  });

  test('duplicatas exatas: grupos e espaço repetido por fonte', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 1000));
    env.write('Fotos/sub/a (1).jpg', bytes(1, 1000));
    env.write('Fotos/outra/qualquer.jpg', bytes(1, 1000));
    env.write('Fotos/b.jpg', bytes(2, 200));
    final id = await env.addFolder('Fotos');
    await env.scan(id);
    await env.hashAll();

    final groups = await env.core.coverage.duplicateGroups();
    expect(groups, hasLength(1));
    expect(groups.single.sizeBytes, 1000);
    expect(
      groups.single.instances.map((i) => i.relPath),
      unorderedEquals(['a.jpg', 'sub/a (1).jpg', 'outra/qualquer.jpg']),
    );
    final per = (await env.core.coverage.report()).perSource[id]!;
    expect(per.duplicateFiles, 2);
    expect(per.duplicateBytes, 2000);
  });

  test('watch recalcula quando a conferência termina', () async {
    final env = await TestEnv.open();
    env.write('Fotos/a.jpg', bytes(1, 500));
    env.write('Copia/a.jpg', bytes(1, 500));
    final a = await env.addFolder('Fotos');
    final b = await env.addFolder('Copia');
    await env.scan(a);
    await env.scan(b);
    final reports = env.core.coverage.watch(interval: const Duration(milliseconds: 50));
    final verified = reports.firstWhere((r) => r.overall.filesIn(BackupState.verified) == 1);
    await env.hashAll();
    final r = await verified.timeout(const Duration(seconds: 30));
    expect(r.pendingFiles, 0);
  });
}
