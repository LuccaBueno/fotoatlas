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
  reorg plan FONTE[:pasta] [--dest P] [--template T] [--conflict suffix|ask] [--to-confirm P]
                                 Prévia da reorganização no mesmo disco (só lê); modelo padrão
                                 "{ano}/{ano}-{mes}-{dia} {momento}"
  reorg start FONTE[:pasta] [...] --yes
                                 Reorganiza (move por renomeação, com diário; Ctrl+C pausa)
  reorg resume OP                Continua uma reorganização (ou um Desfazer)
  reorg undo OP --yes            Desfaz uma reorganização (mostra antes o que vai acontecer)
  reorg resolve ITEM back|rename|leave|retry
                                 Decide um arquivo que espera você (Desfazer ou nome ocupado)
  reorg folders OP [--remove P]… [--yes]
                                 Lista as pastas que ficaram vazias; --remove P --yes remove só P
  reorg status [OP]              Situação das reorganizações (com OP: arquivo por arquivo)
  verify start FONTE[:pasta] [--older-than-days N]
                                 Verifica a integridade (só lê; Ctrl+C pausa)
  verify resume RODADA           Continua uma verificação
  verify status [RODADA]         Situação das verificações (com RODADA: arquivo por arquivo)
  verify problems                Arquivos possivelmente corrompidos e as outras cópias conferidas
  verify restore ITEM --from ITEM2 [--yes]
                                 Restaura pela cópia segura (prévia; nada é substituído)
  verify accept ITEM --yes       Aceita o conteúdo atual (só catálogo)
  verify schedule [on|off] [--every DIAS]
                                 Verificação periódica (leve; nunca celulares)
  verify tick                    Um passo da verificação periódica
  recover                        Roda a recuperação de cópias e reorganizações interrompidas

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
      stdout.writeln('RECOVER_REORG ${await core.reorg.recoverAll()}');
      return 0;

    case ['reorg', ('plan' || 'start') && final mode, final spec, ...final rest]:
      final colon = spec.indexOf(':');
      final source = await _findSource(core, colon < 0 ? spec : spec.substring(0, colon));
      final preview = await core.reorg.preview(
        ReorgRequest(
          sourceId: source,
          folder: colon < 0 ? '' : spec.substring(colon + 1),
          destFolder: _option(rest, '--dest'),
          template: _option(rest, '--template') ?? FolderTemplate.byMoment.pattern,
          conflict: _option(rest, '--conflict') == 'ask' ? ConflictPolicy.ask : ConflictPolicy.suffix,
          toConfirmFolder: _option(rest, '--to-confirm') ?? undatedFolder,
        ),
      );
      stdout.writeln(
        'PREVIEW mover=${preview.moves.length} no_lugar=${preview.alreadyInPlace} outros=${preview.otherFiles} '
        'sem_data_lida=${preview.notReady} renomeados=${preview.renamedForConflict} perguntar=${preview.askConflicts} '
        'a_confirmar=${preview.toConfirm} acompanhantes=${preview.sidecars} pode_comecar=${preview.canStart}'
        '${preview.blocker == null ? '' : ' — ${preview.blocker}'}',
      );
      for (final m in preview.moves) {
        stdout.writeln('  ${m.srcRelPath} -> ${m.dstRelPath}${m.renamedForConflict ? ' (nome já existia)' : ''}');
      }
      if (mode == 'plan') return 0;
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes para reorganizar.');
        return 2;
      }
      if (!preview.canStart) return 1;
      return _followReorg(core, await core.reorg.start(preview));

    case ['reorg', 'resume', final op]:
      final id = await _findOperation(core, op);
      await core.reorg.resume(id);
      return _followReorg(core, id);

    case ['reorg', 'undo', final op, ...final rest]:
      final id = await _findOperation(core, op);
      final check = await core.reorg.undoPreview(id);
      stdout.writeln(
        'UNDO_PREVIEW voltam=${check.ready} mudaram=${check.changed.length} sumiram=${check.missing.length} '
        'ocupados=${check.occupied.length}${check.blocker == null ? '' : ' — ${check.blocker}'}',
      );
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes para desfazer.');
        return 2;
      }
      if (!check.canStart) return 1;
      return _followReorg(core, await core.reorg.undo(id));

    case ['reorg', 'resolve', final item, final decision]:
      final d = switch (decision) {
        'back' => ReorgDecision.moveAnyway,
        'rename' => ReorgDecision.rename,
        'retry' => ReorgDecision.retry,
        _ => ReorgDecision.leave,
      };
      final row = await core.reorg.journal.item(int.parse(item));
      if (row == null) throw SourceException('Item $item não encontrado.');
      await core.reorg.resolve(row.id, d);
      return _followReorg(core, row.operationId);

    case ['reorg', 'folders', final op, ...final rest]:
      final id = await _findOperation(core, op);
      for (final f in await core.reorg.emptyFolders(id)) {
        stdout.writeln('FOLDER ${f.empty ? 'vazia' : 'so_ocultos'} ${f.relPath}');
      }
      final chosen = <String>[];
      for (var i = 0; i < rest.length - 1; i++) {
        if (rest[i] == '--remove') chosen.add(rest[i + 1]);
      }
      if (chosen.isEmpty) return 0;
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes para remover as pastas vazias.');
        return 2;
      }
      stdout.writeln('REMOVED ${await core.reorg.removeEmptyFolders(id, chosen)}');
      return 0;

    case ['reorg', 'status', ...final rest]:
      for (final o in await core.copies.list()) {
        if (o.kind == 'copy' || (rest.isNotEmpty && !o.id.startsWith(rest.first))) continue;
        stdout.writeln(
          'OPERATION ${o.id} ${o.kind} ${o.status} itens=${o.totalItems} movidos=${o.published} '
          'devolvidos=${o.undone} deixados=${o.skipped} falhas=${o.failed} atencao=${o.needsAttention} '
          'faltam=${o.remaining}${o.pauseReason == null ? '' : ' — ${o.pauseReason}'}',
        );
        if (rest.isNotEmpty) {
          for (final i in await core.copies.items(o.id)) {
            stdout.writeln(
              '  ${i.id} ${i.state} ${i.srcRelPath} -> ${i.dstRelPath}'
              '${i.errorCode == null ? '' : ' [${i.errorCode}]'}${i.errorMessage == null ? '' : ' — ${i.errorMessage}'}',
            );
          }
        }
      }
      return 0;

    case ['verify', 'start', final spec, ...final rest]:
      final colon = spec.indexOf(':');
      final source = await _findSource(core, colon < 0 ? spec : spec.substring(0, colon));
      final days = _option(rest, '--older-than-days');
      final request = VerifyRequest(
        entries: [VerifyEntry(source, folder: colon < 0 ? '' : spec.substring(colon + 1))],
        olderThanDays: days == null ? null : int.parse(days),
      );
      final estimate = await core.integrity.estimate(request);
      stdout.writeln(
        'ESTIMATE arquivos=${estimate.files} bytes=${estimate.bytes} celular=${estimate.phoneFiles} '
        'desconectados=${estimate.skippedDisconnected} sem_conferir=${estimate.notYetConferred}',
      );
      final run = await core.integrity.start(request);
      if (run == null) {
        stdout.writeln('Nada para verificar agora.');
        return 0;
      }
      return _followVerify(core, run);

    case ['verify', 'resume', final run]:
      await core.integrity.resume(int.parse(run));
      return _followVerify(core, int.parse(run));

    case ['verify', 'tick']:
      // Um passo da verificação periódica (leve; nunca celulares).
      final run = await core.integrity.scheduleTick();
      if (run == null) {
        stdout.writeln('TICK nada a fazer');
        return 0;
      }
      return _followVerify(core, run);

    case ['verify', 'schedule', ...final rest]:
      var s = await core.integrity.schedule();
      final every = _option(rest, '--every');
      if (rest.contains('on') || rest.contains('off') || every != null) {
        s = IntegritySchedule(
          enabled: rest.contains('on') || (!rest.contains('off') && s.enabled),
          everyDays: every == null ? s.everyDays : int.parse(every),
        );
        await core.integrity.setSchedule(s);
      }
      stdout.writeln('SCHEDULE ligada=${s.enabled} a_cada_dias=${s.everyDays}');
      return 0;

    case ['verify', 'status', ...final rest]:
      for (final r in await core.integrity.runs()) {
        if (rest.isNotEmpty && '${r.id}' != rest.first) continue;
        stdout.writeln(_runLine(r));
        if (rest.isNotEmpty) {
          for (final c in await core.integrity.checks(r.id)) {
            stdout.writeln(
              '  ${c.instanceId} ${c.result} ${c.sourceName}:${c.relPath}${c.reason == null ? '' : ' — ${c.reason}'}',
            );
          }
        }
      }
      return 0;

    case ['verify', 'problems']:
      final problems = await core.integrity.problems();
      if (problems.isEmpty) stdout.writeln('Nenhum arquivo possivelmente corrompido.');
      for (final p in problems) {
        stdout.writeln('PROBLEM ${p.instanceId} ${p.sourceName}:${p.relPath} copias=${p.otherCopies.length}');
        for (final c in p.otherCopies) {
          stdout.writeln(
            '  COPY ${c.instanceId} ${c.sourceName}:${c.relPath} conectada=${c.connected} '
            'mesmo_disco=${c.samePhysicalDisk}',
          );
        }
      }
      return 0;

    case ['verify', 'restore', final item, ...final rest]:
      final from = _option(rest, '--from');
      if (from == null) throw SourceException('Diga de qual cópia restaurar: --from ITEM (veja "verify problems").');
      final request = await core.integrity.restoreRequest(int.parse(item), fromInstanceId: int.parse(from));
      final preview = await core.copies.preview(request);
      stdout.writeln(
        'PREVIEW itens=${preview.items.length} ja_no_destino=${preview.alreadyThere} '
        'indisponiveis=${preview.unavailable.length} pode_comecar=${preview.canStart}'
        '${preview.blocker == null ? '' : ' — ${preview.blocker}'}',
      );
      for (final i in preview.items) {
        stdout.writeln('  ${i.srcRelPath} -> ${i.dstRelPath}');
      }
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes para restaurar (cópia conferida; nada é substituído).');
        return 2;
      }
      if (!preview.canStart) return 1;
      return _followCopy(core, await core.copies.start(preview));

    case ['verify', 'accept', final item, ...final rest]:
      if (!rest.contains('--yes')) {
        stderr.writeln('Confirme com --yes: o conteúdo atual do arquivo passa a valer.');
        return 2;
      }
      stdout.writeln('ACCEPTED ${await core.integrity.acceptAsIs(int.parse(item))}');
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

Future<int> _followReorg(FotoAtlasCore core, String id) async {
  stdout.writeln('OPERATION $id');
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('Pausando…');
    core.reorg.pause(id);
  });
  await core.reorg.waitIdle();
  await sigint.cancel();
  final o = (await core.copies.view(id))!;
  stdout.writeln(
    'REORG ${o.id} ${o.kind} ${o.status} movidos=${o.published} deixados=${o.skipped} falhas=${o.failed} '
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

String _runLine(IntegrityRunView r) =>
    'RUN ${r.id} ${r.scheduled ? 'periodica' : 'manual'} ${r.status} arquivos=${r.filesChecked}/${r.filesTotal} '
    'inalterados=${r.count(CheckResult.unchanged)} alterados=${r.count(CheckResult.changedLegit)} '
    'corrompidos=${r.count(CheckResult.possiblyCorrupt)} nao_lidos=${r.count(CheckResult.unreadable)} '
    'nao_encontrados=${r.count(CheckResult.missing)}${r.message == null ? '' : ' — ${r.message}'}';

/// Acompanha a verificação até terminar ou pausar; Ctrl+C pausa.
Future<int> _followVerify(FotoAtlasCore core, int runId) async {
  stdout.writeln('VERIFY_RUN $runId');
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    stdout.writeln('Pausando…');
    core.integrity.pause(runId);
  });
  await core.integrity.waitIdle();
  await sigint.cancel();
  final r = (await core.integrity.runs()).firstWhere((r) => r.id == runId);
  stdout.writeln(_runLine(r));
  return r.status == RunStatus.completed || r.status == RunStatus.paused ? 0 : 1;
}
