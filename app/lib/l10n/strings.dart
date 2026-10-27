/// Textos de domínio em PT-BR simples (spec §3.1). Nada de "hash", "MTP" ou
/// "WAL" aqui.
library;

import 'package:fotoatlas_core/fotoatlas_core.dart';

String sourceKindLabel(String kind) => switch (kind) {
  'external_hd' => 'HD externo',
  'internal' => 'Disco interno',
  'usb_stick' => 'Pendrive',
  'memory_card' => 'Cartão de memória',
  'phone' => 'Celular',
  'folder' => 'Pasta',
  _ => 'Dispositivo',
};

String scanStatusLabel(String status) => switch (status) {
  'running' => 'Escaneando',
  'paused' => 'Pausado',
  'interrupted' => 'Interrompido',
  'completed' => 'Concluído',
  'cancelled' => 'Cancelado',
  'failed' => 'Falhou',
  _ => status,
};

/// Rótulos das situações de backup (spec §3.1).
String backupStateLabel(BackupState state) => switch (state) {
  BackupState.single => 'Só 1 cópia',
  BackupState.probable => 'Copiado, falta conferir',
  BackupState.verified => 'Cópia conferida',
  BackupState.independent => 'Backup em disco independente',
  BackupState.unknown => 'Situação desconhecida',
};

/// Explicação curta de cada situação.
String backupStateHint(BackupState state) => switch (state) {
  BackupState.single => 'Se este dispositivo falhar, estes arquivos se perdem.',
  BackupState.probable =>
    'Há um arquivo com o mesmo nome e tamanho em outro lugar; o conteúdo ainda vai ser conferido.',
  BackupState.verified => 'Há outra cópia com conteúdo idêntico, mas no mesmo disco.',
  BackupState.independent => 'Há cópia idêntica em outro disco físico.',
  BackupState.unknown => 'O conteúdo ainda não foi conferido.',
};

/// Nome dos tipos do filtro de escopo.
String scopeTypeLabel(ScopeFileType type) => switch (type) {
  ScopeFileType.photo => 'Fotos',
  ScopeFileType.raw => 'RAW',
  ScopeFileType.video => 'Vídeos',
  ScopeFileType.other => 'Outros arquivos',
};
