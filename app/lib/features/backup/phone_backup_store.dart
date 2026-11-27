import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

/// Onde o assistente "Fazer backup do celular" parou (para continuar depois de
/// pausar ou de fechar o app). Só o catálogo; nenhum arquivo.
class PhoneBackupSession {
  const PhoneBackupSession({
    required this.phoneId,
    required this.hdId,
    this.step = 0,
    this.folder = defaultFolder,
    this.template = '{original}',
    this.copyOperationId,
  });

  static const defaultFolder = 'Backup do celular';

  final String phoneId;
  final String hdId;

  /// Passo atual (0 = escolher … 5 = prévia e cópia).
  final int step;
  final String folder;
  final String template;
  final String? copyOperationId;

  PhoneBackupSession copyWith({int? step, String? folder, String? template, String? copyOperationId}) =>
      PhoneBackupSession(
        phoneId: phoneId,
        hdId: hdId,
        step: step ?? this.step,
        folder: folder ?? this.folder,
        template: template ?? this.template,
        copyOperationId: copyOperationId ?? this.copyOperationId,
      );

  Map<String, Object?> toJson() => {
    'phoneId': phoneId,
    'hdId': hdId,
    'step': step,
    'folder': folder,
    'template': template,
    'copyOperationId': copyOperationId,
  };

  static PhoneBackupSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final phone = j['phoneId'], hd = j['hdId'];
    if (phone is! String || hd is! String) return null;
    return PhoneBackupSession(
      phoneId: phone,
      hdId: hd,
      step: (j['step'] as num?)?.toInt() ?? 0,
      folder: (j['folder'] as String?) ?? defaultFolder,
      template: (j['template'] as String?) ?? '{original}',
      copyOperationId: j['copyOperationId'] as String?,
    );
  }
}

/// Guarda a sessão do assistente.
abstract interface class PhoneBackupStore {
  Future<PhoneBackupSession?> load();
  Future<void> save(PhoneBackupSession? session);
}

/// Na memória (testes e padrão sem catálogo).
class MemoryPhoneBackupStore implements PhoneBackupStore {
  PhoneBackupSession? _session;

  @override
  Future<PhoneBackupSession?> load() async => _session;

  @override
  Future<void> save(PhoneBackupSession? session) async => _session = session;
}

/// No catálogo (tabela `settings`), para sobreviver a fechar o app.
class CatalogPhoneBackupStore implements PhoneBackupStore {
  CatalogPhoneBackupStore(this.settings);
  final SettingsStore settings;
  static const key = 'phoneBackup.session';

  @override
  Future<PhoneBackupSession?> load() async {
    final v = await settings.get(key);
    return PhoneBackupSession.fromJson(v is String ? jsonDecode(v) : v);
  }

  @override
  Future<void> save(PhoneBackupSession? session) => settings.set(key, session?.toJson());
}

final phoneBackupStoreProvider = Provider<PhoneBackupStore>((ref) => MemoryPhoneBackupStore());

/// Sessão salva (recarregada com `ref.invalidate`).
final phoneBackupSessionProvider = FutureProvider<PhoneBackupSession?>(
  (ref) => ref.watch(phoneBackupStoreProvider).load(),
);
