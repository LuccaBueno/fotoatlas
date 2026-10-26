import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:fotoatlas_core/fotoatlas_core.dart';

const _usage = '''
FotoAtlas — linha de comando (diagnóstico e testes)

Uso: fotoatlas_cli [--home PASTA] [--no-helper] COMANDO

Comandos:
  volumes [--json]               Lista as unidades conectadas
  sources list                   Lista as fontes cadastradas
  sources add CAMINHO [--name N] Cadastra uma pasta ou unidade
  scan start FONTE               Escaneia (retoma se houver um pausado)
  scan resume ID                 Retoma um escaneamento pelo número
  scan status [FONTE]            Mostra os últimos escaneamentos

FONTE pode ser o nome, o id ou o começo do id.
--home (ou FOTOATLAS_HOME) troca a pasta do catálogo.
''';

Future<void> main(List<String> arguments) async {
  final args = List.of(arguments);
  String? home;
  final homeIndex = args.indexOf('--home');
  if (homeIndex >= 0 && homeIndex + 1 < args.length) {
    home = args[homeIndex + 1];
    args.removeRange(homeIndex, homeIndex + 2);
  }
  final noHelper = args.remove('--no-helper');
  if (args.isEmpty || args.first == 'help' || args.contains('--help')) {
    stdout.write(_usage);
    exit(args.isEmpty ? 64 : 0);
  }

  FotoAtlasCore? core;
  try {
    final paths = home != null ? CorePaths(dataDir: home, localDir: '$home\\local') : CorePaths.fromEnvironment();
    core = await FotoAtlasCore.open(paths: paths, useHelper: !noHelper);
    final code = await _run(core, args);
    await core.close();
    exit(code);
  } on SourceException catch (e) {
    stderr.writeln('Erro: ${e.message}');
  } on CatalogInUseException catch (e) {
    stderr.writeln('Erro: $e');
  } on CatalogTooNewException catch (e) {
    stderr.writeln('Erro: $e');
  }
  await core?.close();
  exit(1);
}

Future<int> _run(FotoAtlasCore core, List<String> args) async {
  switch (args) {
    case ['volumes', ...final rest]:
      final volumes = await core.volumes.list();
      if (rest.contains('--json')) {
        stdout.writeln(const JsonEncoder.withIndent('  ').convert([for (final v in volumes) _volumeJson(v)]));
      } else {
        for (final v in volumes.where((v) => !v.isSystem)) {
          final disk = v.primaryDisk;
          stdout.writeln(
            '${v.displayMount ?? '(sem letra)'}  ${v.label?.isNotEmpty == true ? v.label : '(sem nome)'}  '
            '${v.fileSystem ?? '?'}  ${_bytes(v.freeBytes)} livres de ${_bytes(v.totalBytes)}  '
            'disco: ${disk == null ? 'desconhecido' : '${disk.model ?? '?'} (${disk.busType}, identidade ${disk.identityConfidence})'}',
          );
        }
      }
      return 0;

    case ['sources', 'list']:
      final list = await core.sources.list();
      if (list.isEmpty) stdout.writeln('Nenhuma fonte cadastrada.');
      for (final s in list) {
        final state = switch (s.state) {
          SourceState.connected => 'conectada',
          SourceState.disconnected => 'desconectada',
          SourceState.ambiguous => 'precisa confirmar',
        };
        stdout.writeln(
          '${s.id.substring(0, 8)}  ${s.name}  [$state]  ${s.displayPath ?? ''}  '
          '${s.fileCount} arquivos (${s.mediaCount} fotos/vídeos)  '
          'último scan: ${s.lastScan == null ? 'nunca' : '${s.lastScan!.status} #${s.lastScan!.id}'}',
        );
      }
      return 0;

    case ['sources', 'add', final path, ...final rest]:
      final nameIndex = rest.indexOf('--name');
      final name = nameIndex >= 0 && nameIndex + 1 < rest.length ? rest[nameIndex + 1] : null;
      final result = await core.sources.addPath(path, name: name);
      for (final w in result.warnings) {
        stdout.writeln('Aviso: $w');
      }
      stdout.writeln('SOURCE ${result.sourceId}');
      return 0;

    case ['scan', 'start', final source]:
      final id = await _findSource(core, source);
      return _follow(core, await core.scans.start(id));

    case ['scan', 'resume', final scanId]:
      return _follow(core, await core.scans.resume(int.parse(scanId)));

    case ['scan', 'status', ...final rest]:
      final sourceId = rest.isEmpty ? null : await _findSource(core, rest.first);
      final query = core.catalog.db.select(core.catalog.db.scans);
      if (sourceId != null) query.where((s) => s.sourceId.equals(sourceId));
      query
        ..orderBy([(s) => OrderingTerm.desc(s.id)])
        ..limit(10);
      for (final s in await query.get()) {
        stdout.writeln(
          '#${s.id}  ${s.status}${s.coverage == null ? '' : ' (${s.coverage == 'complete' ? 'completo' : 'parcial'})'}  '
          '${s.filesSeen} arquivos  ${s.dirsDone} pastas  ${s.errorCount} erros',
        );
      }
      return 0;
  }
  stderr.write(_usage);
  return 64;
}

/// Acompanha o scan até o fim; Ctrl+C pausa (pode retomar depois).
Future<int> _follow(FotoAtlasCore core, int scanId) async {
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('Pausando…');
    core.scans.pause(scanId);
  });
  var lastPrint = DateTime.fromMillisecondsSinceEpoch(0);
  final sub = core.scans.progress.where((p) => p.scanId == scanId).listen((p) {
    final now = DateTime.now();
    if (now.difference(lastPrint).inMilliseconds < 1000 && !p.isFinal) return;
    lastPrint = now;
    stdout.writeln(
      'PROGRESS pastas=${p.dirsDone} pendentes=${p.dirsPending} arquivos=${p.filesSeen} erros=${p.errorCount}',
    );
  });
  final result = await core.scans.wait(scanId);
  await sub.cancel();
  await sigint.cancel();
  stdout.writeln(
    'SCAN $scanId ${result.status} arquivos=${result.filesSeen} bytes=${result.bytesSeen} erros=${result.errorCount}'
    '${result.message == null ? '' : ' — ${result.message}'}',
  );
  return result.status == 'completed' || result.status == 'paused' ? 0 : 1;
}

Future<String> _findSource(FotoAtlasCore core, String query) async {
  final list = await core.sources.list();
  final matches = list
      .where((s) => s.id == query || s.id.startsWith(query) || s.name.toLowerCase() == query.toLowerCase())
      .toList();
  if (matches.length == 1) return matches.single.id;
  throw SourceException(matches.isEmpty ? 'Fonte "$query" não encontrada.' : 'Mais de uma fonte combina com "$query".');
}

Map<String, Object?> _volumeJson(VolumeInfo v) => {
  'guidPath': v.guidPath,
  'mountPoints': v.mountPoints,
  'label': v.label,
  'fileSystem': v.fileSystem,
  'serial': v.serial,
  'totalBytes': v.totalBytes,
  'freeBytes': v.freeBytes,
  'driveType': v.driveType,
  'isSystem': v.isSystem,
  'isBoot': v.isBoot,
  'physicalDisks': [
    for (final d in v.physicalDisks)
      {'diskNumber': d.diskNumber, 'model': d.model, 'busType': d.busType, 'identityConfidence': d.identityConfidence},
  ],
};

String _bytes(int? b) {
  if (b == null) return '?';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = b.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
}
