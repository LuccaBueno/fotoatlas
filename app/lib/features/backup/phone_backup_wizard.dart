import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../l10n/format.dart';
import '../library/item_tile.dart';
import '../tasks/tasks_page.dart' show exportOperationReport;
import 'phone_backup_store.dart';

/// Abre o assistente "Fazer backup do celular" (continua de onde parou, se
/// houver uma sessão salva).
Future<void> showPhoneBackupWizard(BuildContext context) =>
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PhoneBackupWizard());

/// Os passos, em palavras simples.
const phoneBackupSteps = [
  'Escolher o celular e o HD',
  'Conhecer o HD inteiro',
  'Ler o celular',
  'Comparar',
  'Onde guardar',
  'Copiar',
];

/// Opções de organização (a primeira é a recomendada).
const phoneBackupTemplates = [
  (FolderTemplate.original, 'Manter as pastas do celular (recomendado)'),
  (FolderTemplate.byMonth, 'Por ano e mês (2024/2024-07)'),
  (FolderTemplate.byDay, 'Por ano e dia (2024/2024-07-13)'),
  (FolderTemplate.flat, 'Tudo na mesma pasta'),
];

Scope _phoneScope(String id) =>
    Scope([ScopeEntry(id)], types: {ScopeFileType.photo, ScopeFileType.raw, ScopeFileType.video});
Scope _hdScope(String id) => Scope([ScopeEntry(id)]);

/// Backup do celular em um assistente (Fase 9, item f): escolhe o celular e o
/// HD, garante que o HD foi escaneado inteiro e conferido, lê e confere o
/// celular, compara pelo conteúdo, pergunta onde guardar e copia com a cópia
/// segura. Pode pausar e continuar a qualquer momento; nada é apagado do celular.
class PhoneBackupWizard extends ConsumerStatefulWidget {
  const PhoneBackupWizard({super.key});

  @override
  ConsumerState<PhoneBackupWizard> createState() => _PhoneBackupWizardState();
}

class _PhoneBackupWizardState extends ConsumerState<PhoneBackupWizard> {
  bool _loaded = false;
  int _step = 0;
  String? _phoneId;
  String? _hdId;

  /// Escolhas do passo 1: id de fonte, `dev:<id>` (celular a cadastrar) ou
  /// `vol:<letra>` (unidade a cadastrar).
  String? _phoneChoice;
  String? _hdChoice;
  List<(DeviceInfo, String?)>? _devices;
  List<(VolumeInfo, String?)>? _drives;
  String _template = FolderTemplate.original.pattern;
  final _folder = TextEditingController(text: PhoneBackupSession.defaultFolder);
  String? _copyOpId;

  /// Escaneamento do celular já feito nesta sessão do assistente.
  bool _phoneScanned = false;
  CompareSummary? _summary;
  List<CompareItem> _sample = const [];
  bool _comparing = false;
  CopyPreview? _preview;
  bool _previewing = false;
  Timer? _previewDebounce;
  String? _error;

  @override
  void initState() {
    super.initState();
    _restore();
    _refreshConnected();
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _folder.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    final s = await ref.read(phoneBackupStoreProvider).load();
    if (!mounted) return;
    setState(() {
      _loaded = true;
      if (s != null) {
        _phoneId = _phoneChoice = s.phoneId;
        _hdId = _hdChoice = s.hdId;
        _step = s.step.clamp(0, phoneBackupSteps.length - 1);
        _folder.text = s.folder;
        _template = s.template;
        _copyOpId = s.copyOperationId;
        // O celular é lido de novo ao continuar (pode ter fotos novas).
        if (_step > 2 && _copyOpId == null) _step = 2;
      }
    });
    if (_step == 3) unawaited(_compare());
    if (_step >= 4 && _copyOpId == null) _schedulePreview();
  }

  Future<void> _save() async {
    final phone = _phoneId, hd = _hdId;
    if (phone == null || hd == null) return;
    await ref
        .read(phoneBackupStoreProvider)
        .save(
          PhoneBackupSession(
            phoneId: phone,
            hdId: hd,
            step: _step,
            folder: _folder.text,
            template: _template,
            copyOperationId: _copyOpId,
          ),
        );
    ref.invalidate(phoneBackupSessionProvider);
  }

  Future<void> _go(int step) async {
    setState(() {
      _step = step;
      _error = null;
    });
    await _save();
    if (step == 3) await _compare();
    if (step == 4 || step == 5) _schedulePreview();
  }

  // --- Ações -----------------------------------------------------------------------

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) setState(() => _error = e is SourceException ? e.message : '$e');
    }
  }

  Future<void> _scan(String sourceId) => _guard(() async {
    await ref.read(backendProvider).startScan(sourceId);
  });

  Future<void> _compare() async {
    final phone = _phoneId, hd = _hdId;
    if (phone == null || hd == null) return;
    setState(() => _comparing = true);
    await _guard(() async {
      final backend = ref.read(backendProvider);
      final summary = await backend.compare(_phoneScope(phone), _hdScope(hd));
      final sample = await backend.compareItems(_phoneScope(phone), _hdScope(hd), CompareList.missing, limit: 8);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _sample = sample;
      });
    });
    if (mounted) setState(() => _comparing = false);
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 300), _makePreview);
  }

  Future<void> _makePreview() async {
    final phone = _phoneId, hd = _hdId;
    if (phone == null || hd == null || !mounted) return;
    setState(() => _previewing = true);
    await _guard(() async {
      final backend = ref.read(backendProvider);
      final ids = await backend.compareMissingContentIds(_phoneScope(phone), _hdScope(hd));
      final preview = await backend.previewCopy(
        CopyRequest(
          contentIds: ids,
          destSourceId: hd,
          destFolder: cleanFolder(_folder.text),
          template: _template,
          preferSourceIds: [phone],
          origin: 'phone_backup',
        ),
      );
      if (mounted) setState(() => _preview = preview);
    });
    if (mounted) setState(() => _previewing = false);
    await _save();
  }

  Future<void> _startCopy() async {
    final preview = _preview;
    if (preview == null || !preview.canStart) return;
    await _guard(() async {
      final id = await ref.read(backendProvider).startCopy(preview);
      setState(() => _copyOpId = id);
      await _save();
    });
  }

  /// Pausa o que estiver em andamento deste backup e fecha (continua depois).
  Future<void> _pauseAndClose() async {
    final backend = ref.read(backendProvider);
    final scans = ref.read(scanProgressProvider).value ?? const {};
    for (final id in [_phoneId, _hdId]) {
      final p = scans[id];
      if (p != null) await backend.pauseScan(p.scanId);
    }
    if (backend.hashStatus.running) await backend.pauseHash();
    final op = _copyOpId;
    if (op != null) await backend.pauseCopy(op);
    await _save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _finish() async {
    await ref.read(phoneBackupStoreProvider).save(null);
    ref.invalidate(phoneBackupSessionProvider);
    if (mounted) Navigator.pop(context);
  }

  // --- Tela ------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final sources = ref.watch(sourcesProvider).value ?? const <SourceView>[];
    SourceView? byId(String? id) => sources.where((s) => s.id == id).firstOrNull;
    final phone = byId(_phoneId), hd = byId(_hdId);
    return Dialog(
      key: const ValueKey('phone-backup'),
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: size.width.clamp(0, 1100).toDouble(),
        height: size.height - 48,
        child: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepList(current: _step),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Passo ${_step + 1} de ${phoneBackupSteps.length}: ${phoneBackupSteps[_step]}',
                                  key: const ValueKey('phone-backup-title'),
                                  style: theme.textTheme.titleLarge,
                                ),
                              ),
                              TextButton.icon(
                                key: const ValueKey('phone-backup-pause'),
                                onPressed: _pauseAndClose,
                                icon: const Icon(Icons.pause),
                                label: const Text('Pausar e continuar depois'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Nada é apagado do celular: as fotos só são lidas e copiadas, e cada cópia é conferida.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                            ),
                          Expanded(child: SingleChildScrollView(child: _body(context, sources, phone, hd))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _body(BuildContext context, List<SourceView> sources, SourceView? phone, SourceView? hd) => switch (_step) {
    0 => _chooseStep(context, sources, phone, hd),
    1 => _hdStep(context, hd),
    2 => _phoneStep(context, phone),
    3 => _compareStep(context, phone, hd),
    4 => _destStep(context, hd),
    _ => _copyStep(context, phone, hd),
  };

  Widget _nav({VoidCallback? next, String nextLabel = 'Continuar', bool back = true}) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Row(
      children: [
        if (back && _step > 0)
          TextButton(
            key: const ValueKey('phone-backup-back'),
            onPressed: () => _go(_step - 1),
            child: const Text('Voltar'),
          ),
        const Spacer(),
        FilledButton(key: const ValueKey('phone-backup-next'), onPressed: next, child: Text(nextLabel)),
      ],
    ),
  );

  // 1) Escolher o celular e o HD: o que está conectado agora (cadastrados ou não).
  Widget _chooseStep(BuildContext context, List<SourceView> sources, SourceView? phone, SourceView? hd) {
    final theme = Theme.of(context);
    final devices = _devices ?? const <(DeviceInfo, String?)>[];
    final drives = _drives ?? const <(VolumeInfo, String?)>[];
    final registeredPhones = sources.where((s) => s.kind == 'phone').toList();
    final disks = sources.where((s) => s.kind != 'phone').toList();
    Widget option({
      required String key,
      required String title,
      required String subtitle,
      required bool selected,
      required bool enabled,
      required VoidCallback onTap,
    }) => Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        key: ValueKey(key),
        enabled: enabled,
        leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: enabled ? onTap : null,
      ),
    );

    final phoneOptions = <Widget>[
      for (final s in registeredPhones)
        option(
          key: 'pb-phone-${s.id}',
          title: s.name,
          subtitle: s.state == SourceState.connected ? 'Conectado' : 'Desconectado — conecte para escolher',
          selected: _phoneChoice == s.id,
          enabled: s.state == SourceState.connected,
          onTap: () => setState(() => _phoneChoice = s.id),
        ),
      for (final (d, sid) in devices)
        if (sid == null)
          option(
            key: 'pb-phone-dev-${d.deviceId}',
            title: '${d.friendlyName}${d.simulated ? ' (simulado)' : ''}',
            subtitle: d.status == 'ok'
                ? 'Conectado — vai ser cadastrado agora'
                : 'Desbloqueie o celular e permita o acesso (${d.status})',
            selected: _phoneChoice == 'dev:${d.deviceId}',
            enabled: d.status == 'ok',
            onTap: () => setState(() => _phoneChoice = 'dev:${d.deviceId}'),
          ),
    ];
    final diskOptions = <Widget>[
      for (final s in disks)
        option(
          key: 'pb-hd-${s.id}',
          title: s.name,
          subtitle: s.state == SourceState.connected
              ? 'Conectado${s.freeBytes == null ? '' : ' · ${formatBytes(s.freeBytes)} livres'}'
              : 'Desconectado — conecte para escolher',
          selected: _hdChoice == s.id,
          enabled: s.state == SourceState.connected,
          onTap: () => setState(() => _hdChoice = s.id),
        ),
      for (final (v, sid) in drives)
        if (sid == null && !v.isSystem && v.displayMount != null)
          option(
            key: 'pb-hd-vol-${v.displayMount}',
            title: '${v.label?.isNotEmpty == true ? v.label : 'Unidade sem nome'} (${v.displayMount})',
            subtitle: 'Conectado — vai ser cadastrado agora · ${formatBytes(v.freeBytes)} livres',
            selected: _hdChoice == 'vol:${v.displayMount}',
            enabled: true,
            onTap: () => setState(() => _hdChoice = 'vol:${v.displayMount}'),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Escolha o celular de onde vêm as fotos e o HD onde elas vão ficar guardadas. Aparecem os '
                'dispositivos conectados agora; um que ainda não foi cadastrado é cadastrado ao continuar.',
              ),
            ),
            TextButton.icon(
              key: const ValueKey('pb-refresh'),
              onPressed: _refreshConnected,
              icon: const Icon(Icons.refresh),
              label: const Text('Procurar de novo'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Celular', style: theme.textTheme.titleMedium),
        if (phoneOptions.isEmpty)
          const Padding(
            key: ValueKey('phone-backup-no-phone'),
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nenhum celular conectado. Conecte o celular pelo cabo USB e desbloqueie a tela. No Android, escolha '
              '"Transferência de arquivos"; no iPhone, toque em "Confiar". Depois clique em "Procurar de novo".',
            ),
          ),
        ...phoneOptions,
        const SizedBox(height: 16),
        Text('HD de destino', style: theme.textTheme.titleMedium),
        if (diskOptions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Nenhum HD conectado. Conecte o HD e clique em "Procurar de novo".'),
          ),
        ...diskOptions,
        _nav(next: _phoneChoice != null && _hdChoice != null ? _confirmChoice : null),
      ],
    );
  }

  Future<void> _refreshConnected() async {
    final backend = ref.read(backendProvider);
    List<(DeviceInfo, String?)> devices = const [];
    List<(VolumeInfo, String?)> drives = const [];
    try {
      devices = await backend.listDevices();
    } on Object {
      // Sem leitura de celulares agora: só os cadastrados aparecem.
    }
    try {
      drives = await backend.listDrives();
    } on Object {
      // Idem para as unidades.
    }
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _drives = drives;
    });
  }

  /// Cadastra o que ainda não estava cadastrado e segue.
  Future<void> _confirmChoice() => _guard(() async {
    final backend = ref.read(backendProvider);
    var phone = _phoneChoice!, hd = _hdChoice!;
    if (phone.startsWith('dev:')) phone = (await backend.addPhone(phone.substring(4))).sourceId;
    if (hd.startsWith('vol:')) hd = (await backend.addPath(hd.substring(4))).sourceId;
    setState(() {
      _phoneId = _phoneChoice = phone;
      _hdId = _hdChoice = hd;
    });
    await _go(1);
  });

  /// Progresso do escaneamento e da conferência de [s]; `true` = tudo pronto.
  (bool, Widget) _scanAndHash(
    BuildContext context,
    SourceView s, {
    required bool needScan,
    required VoidCallback onScan,
  }) {
    final theme = Theme.of(context);
    final scan = (ref.watch(scanProgressProvider).value ?? const {})[s.id];
    final hash = ref.watch(hashStatusProvider).value;
    final per = hash?.perSource[s.id];
    final hashing = per != null && per.done < per.total;
    if (scan != null) {
      return (
        false,
        Column(
          key: const ValueKey('pb-scanning'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text('Escaneando "${s.name}"… ${plural(scan.filesSeen, 'arquivo encontrado', 'arquivos encontrados')}.'),
          ],
        ),
      );
    }
    if (needScan) {
      return (
        false,
        FilledButton.tonalIcon(
          key: const ValueKey('pb-scan'),
          onPressed: onScan,
          icon: const Icon(Icons.search),
          label: Text('Escanear "${s.name}"'),
        ),
      );
    }
    if (hashing) {
      final remaining = hash?.remaining;
      return (
        false,
        Column(
          key: const ValueKey('pb-hashing'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: per.total == 0 ? null : per.done / per.total),
            const SizedBox(height: 8),
            Text(
              'Conferindo o conteúdo de "${s.name}": ${formatInt(per.done)} de ${plural(per.total, 'arquivo', 'arquivos')}'
              '${remaining == null ? '' : ' · faltam cerca de ${formatDuration(remaining)}'}.',
            ),
            if (hash?.paused ?? false)
              TextButton(
                key: const ValueKey('pb-hash-resume'),
                onPressed: () => ref.read(backendProvider).startHash(),
                child: const Text('Continuar a conferência'),
              ),
          ],
        ),
      );
    }
    return (
      true,
      Row(
        key: const ValueKey('pb-ready'),
        children: [
          Icon(Icons.check_circle, color: StatusColors.of(context).verified),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '"${s.name}" está pronto: ${plural(s.mediaCount, 'foto ou vídeo', 'fotos e vídeos')} conhecidos e conferidos.',
              style: theme.textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }

  // 2) O HD inteiro.
  Widget _hdStep(BuildContext context, SourceView? hd) {
    if (hd == null) return const Text('O HD escolhido não está mais cadastrado. Volte e escolha outro.');
    final whole = hd.wholeScannedAt != null;
    final (ready, progress) = _scanAndHash(context, hd, needScan: !whole, onScan: () => _scan(hd.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          whole
              ? 'O HD "${hd.name}" foi escaneado por inteiro em ${formatDateTime(hd.wholeScannedAt!)}. Só falta '
                    'garantir que o conteúdo de tudo foi conferido.'
              : 'Antes de copiar, preciso conhecer o HD "${hd.name}" inteiro. Senão posso copiar fotos que você já '
                    'tem nele — em outra pasta ou com outro nome. O escaneamento só lê: nada no HD muda.',
          key: const ValueKey('pb-hd-text'),
        ),
        const SizedBox(height: 16),
        progress,
        _nav(next: ready && whole ? () => _go(2) : null),
      ],
    );
  }

  // 3) O celular.
  Widget _phoneStep(BuildContext context, SourceView? phone) {
    if (phone == null) return const Text('O celular escolhido não está mais cadastrado. Volte e escolha outro.');
    if (phone.state != SourceState.connected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Text('Conecte "${phone.name}" pelo cabo USB e desbloqueie a tela para continuar.'), _nav()],
      );
    }
    final scanning = (ref.watch(scanProgressProvider).value ?? const {})[phone.id] != null;
    final (ready, progress) = _scanAndHash(
      context,
      phone,
      needScan: !_phoneScanned && !scanning,
      onScan: () async {
        await _scan(phone.id);
        if (mounted) setState(() => _phoneScanned = true);
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Agora leio o celular "${phone.name}" (só leitura) e confiro o conteúdo de cada foto e vídeo. Pelo cabo '
          'USB isso pode demorar; você pode pausar e continuar depois. Mantenha o celular desbloqueado.',
        ),
        const SizedBox(height: 16),
        progress,
        _nav(next: ready && _phoneScanned ? () => _go(3) : null),
      ],
    );
  }

  // 4) Comparar.
  Widget _compareStep(BuildContext context, SourceView? phone, SourceView? hd) {
    final theme = Theme.of(context);
    final s = _summary;
    if (_comparing || s == null || phone == null || hd == null) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
      );
    }
    final incomplete = s.verdict == CompareVerdict.incomplete;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comparei "${phone.name}" com o HD "${hd.name}" inteiro, pelo conteúdo (nomes e pastas não importam).'),
        const SizedBox(height: 12),
        Text(
          key: const ValueKey('pb-compare-result'),
          '${plural(s.inBoth.contents, 'foto do celular já está', 'fotos do celular já estão')} no HD (não serão '
          'copiadas) · ${plural(s.missing.contents, 'foto ainda não está', 'fotos ainda não estão')} '
          '(${formatBytes(s.missing.bytes)}).',
          style: theme.textTheme.titleMedium,
        ),
        if (incomplete) ...[
          const SizedBox(height: 8),
          Text(
            key: const ValueKey('pb-incomplete'),
            '${plural(s.unverifiedTotal, 'arquivo ainda não foi conferido', 'arquivos ainda não foram conferidos')}: '
            'o resultado ainda não é definitivo.',
            style: TextStyle(color: StatusColors.of(context).attention),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(backendProvider).startHash();
              await _compare();
            },
            child: const Text('Conferir agora e comparar de novo'),
          ),
        ],
        if (_sample.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Alguns exemplos do que ainda não está no HD:'),
          const SizedBox(height: 8),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sample.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Tooltip(
                message: _sample[i].relPath.replaceAll('/', ' › '),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(
                    dimension: 96,
                    child: _sample[i].contentId == null
                        ? const Icon(Icons.photo)
                        : Thumbnail(contentId: _sample[i].contentId!, mediaType: 'photo', size: 96),
                  ),
                ),
              ),
            ),
          ),
          TextButton.icon(
            key: const ValueKey('pb-full-list'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _MissingListDialog(phone: _phoneScope(phone.id), hd: _hdScope(hd.id)),
            ),
            icon: const Icon(Icons.list),
            label: Text('Ver a lista completa (${formatInt(s.missing.contents)})'),
          ),
        ],
        if (s.missing.contents == 0 && !incomplete)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              key: const ValueKey('pb-already-done'),
              'Sim, 100%: tudo do celular já está no HD. Não há nada para copiar.',
              style: theme.textTheme.titleMedium?.copyWith(color: StatusColors.of(context).verified),
            ),
          ),
        _nav(
          next: s.missing.contents == 0 && !incomplete ? _finish : () => _go(4),
          nextLabel: s.missing.contents == 0 && !incomplete ? 'Terminar' : 'Continuar',
        ),
      ],
    );
  }

  // 5) Onde guardar.
  Widget _destStep(BuildContext context, SourceView? hd) {
    final theme = Theme.of(context);
    final p = _preview;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Em que pasta do HD "${hd?.name ?? '?'}" as fotos vão ficar, e como organizar.'),
        const SizedBox(height: 12),
        SizedBox(
          width: 420,
          child: TextField(
            key: const ValueKey('pb-folder'),
            controller: _folder,
            decoration: const InputDecoration(labelText: 'Pasta no HD', border: OutlineInputBorder()),
            onChanged: (_) => _schedulePreview(),
          ),
        ),
        const SizedBox(height: 12),
        for (final (t, label) in phoneBackupTemplates)
          ListTile(
            key: ValueKey('pb-template-${t.pattern}'),
            dense: true,
            leading: Icon(_template == t.pattern ? Icons.radio_button_checked : Icons.radio_button_off),
            title: Text(label),
            onTap: () {
              setState(() => _template = t.pattern);
              _schedulePreview();
            },
          ),
        const SizedBox(height: 12),
        Text('Como vai ficar no HD', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (_previewing || p == null)
          const LinearProgressIndicator()
        else
          _FolderTree(hdName: hd?.name ?? 'HD', preview: p),
        _nav(next: p != null && !_previewing ? () => _go(5) : null),
      ],
    );
  }

  // 6) Prévia, cópia e relatório.
  Widget _copyStep(BuildContext context, SourceView? phone, SourceView? hd) {
    final theme = Theme.of(context);
    final opId = _copyOpId;
    if (opId == null) {
      final p = _preview;
      if (p == null || _previewing) return const LinearProgressIndicator();
      final where = [hd?.name ?? '?', if (cleanFolder(_folder.text).isNotEmpty) cleanFolder(_folder.text)].join(' › ');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            key: const ValueKey('pb-preview'),
            'Vou copiar ${plural(p.items.length, 'foto ou vídeo', 'fotos e vídeos')} (${formatBytes(p.totalBytes)}) '
            'de "${phone?.name ?? '?'}" para "$where".',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (p.alreadyThere > 0) Text('${plural(p.alreadyThere, 'arquivo já está', 'arquivos já estão')} no destino.'),
          if (p.freeBytes != null) Text('Espaço livre no HD: ${formatBytes(p.freeBytes)}.'),
          if (!p.enoughSpace) Text('Não há espaço suficiente no HD.', style: TextStyle(color: theme.colorScheme.error)),
          if (p.blocker != null) Text(p.blocker!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          const Text(
            'Cada foto é copiada para um arquivo temporário, conferida pelo conteúdo e só então aparece no HD. Nada '
            'é sobrescrito, e nada é apagado do celular.',
          ),
          _nav(
            next: p.canStart ? _startCopy : null,
            nextLabel: 'Copiar ${plural(p.items.length, 'arquivo', 'arquivos')}',
          ),
        ],
      );
    }
    final ops = ref.watch(operationsProvider).value ?? const <OperationView>[];
    final o = ops.where((x) => x.id == opId).firstOrNull;
    if (o == null) return const LinearProgressIndicator();
    final running = o.status == OpStatus.running || o.status == OpStatus.confirmed;
    final backend = ref.read(backendProvider);
    final s = _summary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (o.isOpen) ...[
          LinearProgressIndicator(value: o.totalItems == 0 ? null : (o.published + o.skipped) / o.totalItems),
          const SizedBox(height: 8),
          Text(
            key: const ValueKey('pb-copying'),
            o.status == OpStatus.paused
                ? 'Cópia pausada: ${formatInt(o.published)} de ${plural(o.totalItems, 'arquivo', 'arquivos')}.'
                : 'Copiando e conferindo: ${formatInt(o.published)} de ${plural(o.totalItems, 'arquivo', 'arquivos')}.',
          ),
          const SizedBox(height: 8),
          if (running)
            OutlinedButton.icon(
              onPressed: () => backend.pauseCopy(o.id),
              icon: const Icon(Icons.pause),
              label: const Text('Pausar a cópia'),
            )
          else if (o.status == OpStatus.paused)
            FilledButton.icon(
              key: const ValueKey('pb-copy-resume'),
              onPressed: () => backend.resumeCopy(o.id),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Continuar a cópia'),
            ),
        ] else ...[
          Text(
            key: const ValueKey('pb-report'),
            'Pronto: ${plural(o.published, 'arquivo copiado e conferido', 'arquivos copiados e conferidos')}'
            '${o.failed > 0 ? ' · ${plural(o.failed, 'não foi copiado', 'não foram copiados')} (veja em Tarefas)' : ''}.',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => exportOperationReport(context, ref, o),
                icon: const Icon(Icons.download),
                label: const Text('Exportar relatório (CSV)'),
              ),
              FilledButton.tonalIcon(
                key: const ValueKey('pb-compare-again'),
                onPressed: _compare,
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Comparar de novo'),
              ),
            ],
          ),
          if (_comparing) const LinearProgressIndicator(),
          if (s != null && !_comparing && s.computedAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5))))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                key: const ValueKey('pb-final'),
                switch (s.verdict) {
                  CompareVerdict.complete => 'Sim, 100%: tudo do celular está no HD.',
                  CompareVerdict.missing =>
                    'Ainda faltam ${plural(s.missing.contents, 'foto', 'fotos')} (${formatBytes(s.missing.bytes)}).',
                  CompareVerdict.incomplete => 'Ainda há arquivos sendo conferidos; compare de novo daqui a pouco.',
                  _ => 'Não há fotos nem vídeos no celular para comparar.',
                },
                style: theme.textTheme.titleMedium?.copyWith(
                  color: s.verdict == CompareVerdict.complete ? StatusColors.of(context).verified : null,
                ),
              ),
            ),
          _nav(next: _finish, nextLabel: 'Terminar', back: false),
        ],
      ],
    );
  }
}

class _StepList extends StatelessWidget {
  const _StepList({required this.current});
  final int current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Backup do celular', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (var i = 0; i < phoneBackupSteps.length; i++)
            ListTile(
              dense: true,
              selected: i == current,
              leading: Icon(
                i < current ? Icons.check_circle : (i == current ? Icons.radio_button_checked : Icons.circle_outlined),
                color: i < current ? StatusColors.of(context).verified : null,
              ),
              title: Text(phoneBackupSteps[i]),
            ),
        ],
      ),
    );
  }
}

/// "Desenho" das pastas que vão ficar no HD.
class _FolderTree extends StatelessWidget {
  const _FolderTree({required this.hdName, required this.preview});
  final String hdName;
  final CopyPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final folders = [...preview.folders]..sort((a, b) => a.relPath.compareTo(b.relPath));
    const max = 12;
    return Container(
      key: const ValueKey('pb-tree'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storage, size: 18),
              const SizedBox(width: 6),
              Text(hdName, style: theme.textTheme.labelLarge),
            ],
          ),
          if (folders.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Text(plural(preview.items.length, 'arquivo', 'arquivos')),
            ),
          for (final f in folders.take(max))
            Padding(
              padding: EdgeInsets.only(left: 24.0 * (1 + '/'.allMatches(f.relPath).length), top: 4),
              child: Row(
                children: [
                  const Icon(Icons.folder_outlined, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${f.relPath.split('/').last} — ${plural(f.files, 'arquivo', 'arquivos')} (${formatBytes(f.bytes)})',
                    ),
                  ),
                ],
              ),
            ),
          if (folders.length > max)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Text('… e mais ${plural(folders.length - max, 'pasta', 'pastas')}'),
            ),
        ],
      ),
    );
  }
}

/// A lista completa do que ainda não está no HD, para conferir.
class _MissingListDialog extends ConsumerStatefulWidget {
  const _MissingListDialog({required this.phone, required this.hd});
  final Scope phone;
  final Scope hd;

  @override
  ConsumerState<_MissingListDialog> createState() => _MissingListDialogState();
}

class _MissingListDialogState extends ConsumerState<_MissingListDialog> {
  final _items = <CompareItem>[];
  bool _more = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || !_more) return;
    setState(() => _loading = true);
    final page = await ref
        .read(backendProvider)
        .compareItems(widget.phone, widget.hd, CompareList.missing, offset: _items.length, limit: 200);
    if (!mounted) return;
    setState(() {
      _items.addAll(page);
      _more = page.length == 200;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('pb-missing-list'),
    title: const Text('O que ainda não está no HD'),
    content: SizedBox(
      width: 640,
      height: 480,
      child: ListView(
        children: [
          for (final i in _items)
            ListTile(
              dense: true,
              leading: const Icon(Icons.photo_outlined),
              title: Text(i.relPath.replaceAll('/', ' › ')),
              trailing: Text(formatBytes(i.sizeBytes)),
            ),
          if (_more) TextButton(onPressed: _load, child: Text(_loading ? 'Carregando…' : 'Mostrar mais')),
        ],
      ),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar'))],
  );
}
