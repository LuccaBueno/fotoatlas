/// Textos de domínio em PT-BR simples (spec §3.1). Nada de "hash", "MTP" ou
/// "WAL" aqui.
library;

import 'package:fotoatlas_core/fotoatlas_core.dart';

import 'format.dart';

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

/// Explicação dos 🟢 quando parte das cópias está em outro disco que o Windows
/// não identifica com certeza (ex.: SSD NVMe com número de série zerado, R1):
/// pode ser um disco diferente, mas não dá para garantir.
String verifiedHint(int verified, int uncertainDisk) {
  if (uncertainDisk == 0) return backupStateHint(BackupState.verified);
  const why = 'o Windows não identifica com certeza um dos discos (ex.: SSD interno)';
  if (uncertainDisk >= verified) {
    return 'Há outra cópia idêntica, mas não dá para confirmar que estão em discos diferentes: $why.';
  }
  return 'Há outra cópia idêntica. Em ${plural(uncertainDisk, 'arquivo', 'arquivos')}, não dá para '
      'confirmar que as cópias estão em discos diferentes: $why.';
}

/// Dica curta para o cartão do dispositivo.
String uncertainDiskShort(int verified, int uncertainDisk) =>
    'Não dá para confirmar que ${uncertainDisk >= verified ? '' : '${formatInt(uncertainDisk)} delas '}'
    'estão em discos diferentes';

/// Nome dos tipos do filtro de escopo.
String scopeTypeLabel(ScopeFileType type) => switch (type) {
  ScopeFileType.photo => 'Fotos',
  ScopeFileType.raw => 'RAW',
  ScopeFileType.video => 'Vídeos',
  ScopeFileType.other => 'Outros arquivos',
};

/// Contador com concordância: "1 arquivo com só 1 cópia", "4 cópias conferidas".
String backupStateCount(BackupState state, int n) => switch (state) {
  BackupState.single => '${plural(n, 'arquivo', 'arquivos')} com só 1 cópia',
  BackupState.probable => '${plural(n, 'copiado', 'copiados')}, falta conferir',
  BackupState.verified => plural(n, 'cópia conferida', 'cópias conferidas'),
  BackupState.independent => '${plural(n, 'arquivo', 'arquivos')} com backup em disco independente',
  BackupState.unknown => '${plural(n, 'arquivo', 'arquivos')} em situação desconhecida',
};

/// Caminho com um só separador: "HD_antigo › pasta2 › notas.txt".
String displayPath(String sourceName, String relPath) =>
    [sourceName, ...relPath.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty)].join(' › ');

/// Aviso do iPhone (spec §13): sem "Manter originais", o HEIC chega como JPG.
const iphoneOriginalsHint =
    'No iPhone, abra Ajustes › Fotos e, em "Transferir para Mac ou PC", escolha "Manter originais". '
    'Senão as fotos chegam convertidas (HEIC vira JPG) e não batem com as originais.';

/// Situação de um celular conectado.
String deviceStatusLabel(String status) => switch (status) {
  'ok' => 'Pronto',
  'locked' => 'Bloqueado',
  _ => 'Falta permitir o acesso',
};

/// Pasta sem o nome da fonte: "DCIM › Camera".
String folderLabel(String relPath) => relPath.split(RegExp(r'[/\\]')).where((p) => p.isNotEmpty).join(' › ');

/// Aviso quando o helper (leitura de dispositivos) cai fora do encerramento.
const helperRestartingMessage =
    'A leitura de dispositivos parou inesperadamente e está sendo reiniciada. O que estava em andamento '
    'foi interrompido sem perder nada: a conferência continua sozinha e o escaneamento continua em "Retomar".';
