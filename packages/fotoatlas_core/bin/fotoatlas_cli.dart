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
  devices                        Lista os celulares conectados (só leitura)
  sources list                   Lista as fontes cadastradas
  sources add CAMINHO [--name N] Cadastra uma pasta ou unidade
  sources add-phone CELULAR [--name N]
                                 Cadastra um celular (número da lista de "devices",
                                 nome ou começo do ID)
  scan start FONTE [--folder P]… Escaneia (retoma se houver um pausado); --folder
                                 escaneia só a pasta P (ex.: "Armazenamento interno/DCIM/Camera");
                                 repita --folder para escanear várias pastas de uma vez
  scan resume ID                 Retoma um escaneamento pelo número
  scan status [FONTE]            Mostra os últimos escaneamentos
  hash run                       Confere o conteúdo dos pendentes (Ctrl+C pausa)
  hash retry [FONTE]             Volta para a fila os que deram erro ou mudaram
  coverage                       Situação de backup (fotos e vídeos)
  compare LADO_A LADO_B [--list L] [--type T]
                                 B contém todo o conteúdo de A?
  scopes list                    Lista os escopos salvos
  scopes save NOME ESCOPO        Salva um escopo com nome
  scopes remove NOME             Remove um escopo salvo (só do catálogo)
  backup [now|list]              Backup do catálogo
  copy plan A DESTINO[:pasta] [--template T] [--conflict suffix|ask]
                                 Prévia de "copiar o que falta de A em DESTINO" (só lê)
  copy start A DESTINO[:pasta] [...] --yes
                                 Copia com conferência (Ctrl+C pausa); --template:
                                 "{ano}/{ano}-{mes}" (padrão), "{original}", "" etc.
  copy resume|retry|export OP    Continua, tenta de novo as falhas ou exporta o relatório (CSV)
  copy status [OP]               Situação das cópias (com OP: arquivo por arquivo)
  recover                        Roda a recuperação de cópias interrompidas e mostra o resultado

FONTE pode ser o nome, o id ou o começo do id.
ESCOPO/LADO: "FONTE[:pasta/sub]" separados por "+" (ex.: "HD:Fotos/2020+Celular"),
  ou "@NOME" para um escopo salvo. --type: photo,raw,video,other.
--list: missing (padrão), only-b, both, unverified-a, unverified-b.
--home (ou FOTOATLAS_HOME) troca a pasta do catálogo.
FOTOATLAS_FAKE_DEVICES=PASTA mostra celulares simulados (testes e demonstração).
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

    case ['devices']:
      final devices = await core.sources.listDevices();
      if (devices.isEmpty) stdout.writeln('Nenhum celular conectado.');
      for (final (i, (d, sourceId)) in devices.indexed) {
        final status = switch (d.status) {
          'ok' => 'pronto',
          'locked' => 'bloqueado',
          _ => 'sem autorização',
        };
        stdout.writeln(
          '${i + 1}  ${d.friendlyName}  [$status]  ${d.platform}${d.simulated ? ' (simulado)' : ''}  '
          '${d.storages.map((s) => s.name).join(', ')}'
          '${sourceId == null ? '' : '  cadastrado: ${sourceId.substring(0, 8)}'}',
        );
        final hint = phoneStatusMessage(d);
        if (hint != null) stdout.writeln('   $hint');
        if (d.isIphone) {
          stdout.writeln('   iPhone: em Ajustes > Fotos > Transferir para Mac ou PC, escolha "Manter originais".');
        }
      }
      return 0;

    case ['sources', 'add-phone', final query, ...final rest]:
      final devices = await core.sources.listDevices();
      final index = int.tryParse(query);
      final matches = [
        for (final (i, (d, _)) in devices.indexed)
          if (index == i + 1 ||
              d.deviceId == query ||
              d.deviceId.startsWith(query) ||
              d.friendlyName.toLowerCase() == query.toLowerCase())
            d,
      ];
      if (matches.length != 1) {
        throw SourceException(
          matches.isEmpty ? 'Celular "$query" não encontrado.' : 'Mais de um celular combina com "$query".',
        );
      }
      final nameIndex = rest.indexOf('--name');
      final name = nameIndex >= 0 && nameIndex + 1 < rest.length ? rest[nameIndex + 1] : null;
      final result = await core.sources.addPhone(matches.single.deviceId, name: name);
      for (final w in result.warnings) {
        stdout.writeln('Aviso: $w');
      }
      stdout.writeln('SOURCE ${result.sourceId}');
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

    case ['scan', 'start', final source, ...final rest]:
      final id = await _findSource(core, source);
      return _follow(core, await core.scans.start(id, folders: _options(rest, '--folder')));

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

    case ['hash', 'run']:
      return _hashRun(core);

    case ['hash', 'retry', ...final rest]:
      final sourceId = rest.isEmpty ? null : await _findSource(core, rest.first);
      stdout.writeln('RETRY ${await core.hashes.retryFailed(sourceId: sourceId)}');
      return 0;

    case ['coverage']:
      final r = await core.coverage.report();
      final names = {for (final s in await core.sources.list()) s.id: s.name};
      stdout.writeln('Fotos e vídeos (conteúdos distintos):');
      for (final state in BackupState.values) {
        stdout.writeln(
          '  ${_stateLabel(state)}: ${r.overall.filesIn(state)} (${_bytes(r.overall.bytesIn(state))})  '
          'COVERAGE ${state.name}=${r.overall.filesIn(state)}',
        );
      }
      stdout.writeln('  Ainda sem conteúdo conferido: ${r.pendingFiles}');
      for (final s in r.perSource.values) {
        stdout.writeln(
          '${names[s.sourceId] ?? s.sourceId}: ${BackupState.values.map((st) => '${st.name}=${s.counts.filesIn(st)}').join(' ')}'
          '  repetidos=${s.duplicateFiles} (${_bytes(s.duplicateBytes)})',
        );
      }
      return 0;

    case ['compare', final sideA, final sideB, ...final rest]:
      final types = _option(rest, '--type');
      final a = await _parseScope(core, sideA, types);
      final b = await _parseScope(core, sideB, types);
      final r = await core.compare.compare(a, b);
      final verdict = switch (r.verdict) {
        CompareVerdict.complete => 'Sim, 100%: B contém todo o conteúdo de A.',
        CompareVerdict.missing =>
          '${r.missing.contents == 1 ? 'Falta 1 arquivo' : 'Faltam ${r.missing.contents} arquivos'} (${_bytes(r.missing.bytes)}) de A em B.',
        CompareVerdict.incomplete =>
          'Resultado incompleto: ${r.unverifiedTotal} arquivos ainda sem conteúdo conferido'
              '${r.missing.contents > 0 ? '; já se sabe que faltam ${r.missing.contents} (${_bytes(r.missing.bytes)})' : ''}.',
        CompareVerdict.emptyA => 'A não tem nenhum arquivo.',
      };
      stdout
        ..writeln(verdict)
        ..writeln('VERDICT ${r.verdict.name}')
        ..writeln(
          'A files=${r.aFiles} bytes=${r.aBytes} contents=${r.aContents} repeated=${r.aRepeated}  '
          'B files=${r.bFiles} bytes=${r.bBytes} contents=${r.bContents} repeated=${r.bRepeated}',
        )
        ..writeln('MISSING contents=${r.missing.contents} bytes=${r.missing.bytes} files=${r.missing.files}')
        ..writeln('ONLY_B contents=${r.onlyInB.contents} bytes=${r.onlyInB.bytes}')
        ..writeln('BOTH contents=${r.inBoth.contents} bytes=${r.inBoth.bytes}');
      for (final issue in r.issues) {
        stdout.writeln(switch (issue) {
          UnverifiedFiles(:final side, :final pending, :final errors, :final changed, :final cloudOnly) =>
            'ISSUE unverified $side pending=$pending errors=$errors changed=$changed cloud=$cloudOnly',
          NeverScanned(:final side, :final sourceName, :final folder) =>
            'ISSUE never_scanned $side $sourceName${folder == null ? '' : ':$folder'}',
          UnreadFolders(:final side, :final sourceName, :final folders) =>
            'ISSUE unread_folders $side $sourceName ${folders.join(', ')}',
          UnknownSource(:final side, :final sourceId) => 'ISSUE unknown_source $side $sourceId',
        });
      }
      for (final w in r.warnings) {
        stdout.writeln(switch (w) {
          DisconnectedSource(:final side, :final sourceName) => 'WARN disconnected $side $sourceName',
          ScopesOverlap(:final aName, :final bName) => 'WARN overlap $aName × $bName',
        });
      }
      final listName = _option(rest, '--list');
      if (listName != null) {
        final list = switch (listName) {
          'only-b' => CompareList.onlyInB,
          'both' => CompareList.inBoth,
          'unverified-a' => CompareList.unverifiedA,
          'unverified-b' => CompareList.unverifiedB,
          _ => CompareList.missing,
        };
        final names = {for (final s in await core.sources.list()) s.id: s.name};
        for (var offset = 0; ; offset += 500) {
          final page = await core.compare.items(a, b, list, offset: offset, limit: 500);
          for (final i in page) {
            stdout.writeln('ITEM ${names[i.sourceId] ?? i.sourceId}:${i.relPath}  ${_bytes(i.sizeBytes)}');
          }
          if (page.length < 500) break;
        }
      }
      return 0;

    case ['scopes', 'list']:
      final saved = await core.compare.savedScopes();
      if (saved.isEmpty) stdout.writeln('Nenhum escopo salvo.');
      final names = {for (final s in await core.sources.list()) s.id: s.name};
      for (final s in saved) {
        final entries = s.scope.entries.map(
          (e) => e.relPath.isEmpty ? names[e.sourceId] : '${names[e.sourceId]}:${e.relPath}',
        );
        stdout.writeln(
          '${s.name}: ${entries.join(' + ')}${s.scope.types == null ? '' : '  (${s.scope.types!.map((t) => t.name).join(',')})'}',
        );
      }
      return 0;

    case ['scopes', 'save', final name, final spec, ...final rest]:
      final saved = await core.compare.saveScope(name, await _parseScope(core, spec, _option(rest, '--type')));
      stdout.writeln('SCOPE ${saved.id} ${saved.name}');
      return 0;

    case ['scopes', 'remove', final name]:
      final saved = (await core.compare.savedScopes()).where((s) => s.name.toLowerCase() == name.toLowerCase());
      if (saved.isEmpty) throw SourceException('Escopo "$name" não encontrado.');
      await core.compare.removeScope(saved.single.id);
      return 0;

    case ['copy', ('plan' || 'start') && final mode, final sideA, final destSpec, ...final rest]:
      final a = await _parseScope(core, sideA, _option(rest, '--type'));
      final colon = destSpec.indexOf(':');
      final dest = await _findSource(core, colon < 0 ? destSpec : destSpec.substring(0, colon));
      final folder = colon < 0 ? '' : destSpec.substring(colon + 1);
      final ids = await core.compare.missingContentIds(a, Scope([ScopeEntry(dest, folder)]));
      final preview = await core.copies.preview(
        CopyRequest(
          contentIds: ids,
          destSourceId: dest,
          destFolder: folder,
          template: _option(rest, '--template') ?? FolderTemplate.byMonth.pattern,
          conflict: _option(rest, '--conflict') == 'ask' ? ConflictPolicy.ask : ConflictPolicy.suffix,
          preferSourceIds: a.sourceIds.toList(),
          origin: 'cli',
        ),
      );
      stdout.writeln(
        'PREVIEW itens=${preview.items.length} bytes=${preview.totalBytes} ja_no_destino=${preview.alreadyThere} '
        'indisponiveis=${preview.unavailable.length} fat32=${preview.tooLargeForFat32.length} '
        'renomeados=${preview.renamedForConflict} perguntar=${preview.askConflicts} '
        'livre=${preview.freeBytes ?? '?'} pode_comecar=${preview.canStart}'
        '${preview.blocker == null ? '' : ' — ${preview.blocker}'}',
      );
      for (final i in preview.items) {
        stdout.writeln('  ${i.srcRelPath} -> ${i.dstRelPath}${i.renamedForConflict ? ' (nome já existia)' : ''}');
      }
      for (final u in [...preview.unavailable, ...preview.tooLargeForFat32]) {
        stdout.writeln('  [fora] ${u.name}: ${u.reason}');
      }
      if (mode == 'plan') return 0;
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes para copiar.');
        return 2;
      }
      if (!preview.canStart) return 1;
      return _followCopy(core, await core.copies.start(preview));

    case ['copy', 'resume', final op]:
      final id = await _findOperation(core, op);
      await core.copies.resume(id);
      return _followCopy(core, id);

    case ['copy', 'retry', final op]:
      final id = await _findOperation(core, op);
      stdout.writeln('RETRY ${await core.copies.retryFailed(id)}');
      return _followCopy(core, id);

    case ['copy', 'status', ...final rest]:
      for (final o in await core.copies.list()) {
        if (rest.isNotEmpty && !o.id.startsWith(rest.first)) continue;
        stdout.writeln(
          'OPERATION ${o.id} ${o.status} itens=${o.totalItems} publicados=${o.published} '
          'ja_tinha=${o.skipped} falhas=${o.failed} atencao=${o.needsAttention} faltam=${o.remaining}'
          '${o.pauseReason == null ? '' : ' — ${o.pauseReason}'}',
        );
        if (rest.isNotEmpty) {
          for (final i in await core.copies.items(o.id)) {
            stdout.writeln(
              '  ${i.seq} ${i.state} ${i.srcRelPath} -> ${i.dstRelPath}'
              '${i.errorMessage == null ? '' : ' — ${i.errorMessage}'}',
            );
          }
        }
      }
      return 0;

    case ['copy', 'export', final op]:
      stdout.write(await core.copies.exportCsv(await _findOperation(core, op)));
      return 0;

    case ['recover']:
      // A recuperação já roda ao abrir o core; aqui ela roda mais uma vez e
      // mostra o resultado (deve ser "nada a fazer").
      final report = await core.copies.recoverAll();
      stdout.writeln('RECOVER $report');
      return 0;

    case ['backup'] || ['backup', 'now']:
      final info = await core.backups.backupNow();
      stdout.writeln('BACKUP ${info.path} ${_bytes(info.sizeBytes)}');
      return 0;

    case ['backup', 'list']:
      for (final b in core.backups.list()) {
        stdout.writeln('${b.createdAt.toLocal()}  ${_bytes(b.sizeBytes)}  ${b.path}');
      }
      return 0;
  }
  stderr.write(_usage);
  return 64;
}

String? _option(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// "FONTE[:pasta]+FONTE2" ou "@NOME" (escopo salvo).
Future<Scope> _parseScope(FotoAtlasCore core, String spec, String? types) async {
  final typeSet = types?.split(',').map((t) => ScopeFileType.values.byName(t.trim())).toSet();
  if (spec.startsWith('@')) {
    final name = spec.substring(1).toLowerCase();
    final saved = (await core.compare.savedScopes()).where((s) => s.name.toLowerCase() == name);
    if (saved.isEmpty) throw SourceException('Escopo salvo "${spec.substring(1)}" não encontrado.');
    final scope = saved.single.scope;
    return typeSet == null ? scope : Scope(scope.entries, types: typeSet);
  }
  final entries = <ScopeEntry>[];
  for (final part in spec.split('+')) {
    final i = part.indexOf(':');
    // "C:\..." não é usado aqui: pastas são relativas à fonte.
    final source = await _findSource(core, i < 0 ? part : part.substring(0, i));
    entries.add(ScopeEntry(source, i < 0 ? '' : part.substring(i + 1)));
  }
  return Scope(entries, types: typeSet);
}

String _stateLabel(BackupState s) => switch (s) {
  BackupState.single => 'Só 1 cópia',
  BackupState.probable => 'Copiado, falta conferir',
  BackupState.verified => 'Cópia conferida',
  BackupState.independent => 'Backup em disco independente',
  BackupState.unknown => 'Situação desconhecida',
};

/// Confere o conteúdo até acabar; Ctrl+C pausa (os pendentes ficam para depois).
Future<int> _hashRun(FotoAtlasCore core) async {
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('Pausando…');
    core.hashes.pause();
  });
  var lastPrint = DateTime.fromMillisecondsSinceEpoch(0);
  final sub = core.hashes.status.listen((s) {
    final now = DateTime.now();
    if (now.difference(lastPrint).inMilliseconds < 1000 && s.running) return;
    lastPrint = now;
    stdout.writeln(
      'PROGRESS feitos=${s.filesDone}/${s.filesTotal} bytes=${s.bytesDone}/${s.bytesTotal} erros=${s.errors}',
    );
  });
  await core.hashes.start();
  await core.hashes.waitIdle();
  await sub.cancel();
  await sigint.cancel();
  final s = core.hashes.current;
  stdout.writeln(
    'HASH ${s.paused ? 'paused' : 'done'} feitos=${s.filesDone} erros=${s.errors} mudaram=${s.changed}'
    '${s.message == null ? '' : ' — ${s.message}'}',
  );
  return 0;
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

/// Acompanha a cópia até terminar ou pausar; Ctrl+C pausa (continua depois).
Future<int> _followCopy(FotoAtlasCore core, String id) async {
  stdout.writeln('OPERATION $id');
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('Pausando…');
    core.copies.pause(id);
  });
  var lastPrint = DateTime.fromMillisecondsSinceEpoch(0);
  final sub = core.copies.progress.where((p) => p.operationId == id).listen((p) {
    final now = DateTime.now();
    if (now.difference(lastPrint).inMilliseconds < 1000) return;
    lastPrint = now;
    stdout.writeln('PROGRESS itens=${p.itemsDone}/${p.itemsTotal} bytes=${p.bytesDone}/${p.bytesTotal}');
  });
  await core.copies.waitIdle();
  await sub.cancel();
  await sigint.cancel();
  final o = (await core.copies.view(id))!;
  stdout.writeln(
    'COPY ${o.id} ${o.status} publicados=${o.published} ja_tinha=${o.skipped} falhas=${o.failed} '
    'atencao=${o.needsAttention} faltam=${o.remaining}${o.pauseReason == null ? '' : ' — ${o.pauseReason}'}',
  );
  return o.status == OpStatus.completed || o.status == OpStatus.paused ? 0 : 1;
}

Future<String> _findOperation(FotoAtlasCore core, String query) async {
  final matches = (await core.copies.list()).where((o) => o.id.startsWith(query)).toList();
  if (matches.length == 1) return matches.single.id;
  throw SourceException(
    matches.isEmpty ? 'Operação "$query" não encontrada.' : 'Mais de uma operação começa com "$query".',
  );
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

/// Todos os valores de uma opção que pode se repetir (`--folder A --folder B`).
List<String> _options(List<String> args, String name) => [
  for (var i = 0; i + 1 < args.length; i++)
    if (args[i] == name) args[i + 1],
];
