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
/// Dizem o que importa para quem não é técnico: tem backup ou não.
String backupStateLabel(BackupState state) => switch (state) {
  BackupState.single => 'Sem backup (só em 1 lugar)',
  BackupState.probable => 'Parece ter cópia (falta conferir)',
  BackupState.verified => 'Tem cópia conferida',
  BackupState.independent => 'Backup em outro disco',
  BackupState.unknown => 'Ainda não dá para saber',
};

/// Explicação curta de cada situação.
String backupStateHint(BackupState state) => switch (state) {
  BackupState.single => 'Sem backup: só existe em um lugar. Se este dispositivo falhar, se perde.',
  BackupState.probable =>
    'Há um arquivo com o mesmo nome e tamanho em outro lugar; o conteúdo ainda vai ser conferido.',
  BackupState.verified =>
    'Tem cópia com conteúdo idêntico, mas no mesmo disco: se esse disco falhar, as duas se perdem.',
  BackupState.independent => 'Backup em outro disco: há cópia idêntica num disco diferente. É a situação mais segura.',
  BackupState.unknown => 'O conteúdo ainda não foi conferido; a situação aparece depois da conferência.',
};

/// Dica de um item, com onde ele está: "Sem backup: este arquivo só existe no Pixel de Teste."
String backupStateItemHint(BackupState state, List<String> places) {
  final where = switch (places.length) {
    0 => '',
    1 => places.first,
    _ => '${places.take(places.length - 1).join(', ')} e ${places.last}',
  };
  return switch (state) {
    BackupState.single => where.isEmpty ? backupStateHint(state) : 'Sem backup: este arquivo só existe em "$where".',
    BackupState.verified =>
      'Tem cópia conferida${where.isEmpty ? '' : ' (em $where)'}, mas no mesmo disco: se ele falhar, as cópias se perdem.',
    BackupState.independent => 'Backup em outro disco${where.isEmpty ? '' : ': está em $where'}.',
    _ => backupStateHint(state),
  };
}

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

/// Contador com concordância: "1 arquivo sem backup (só em 1 lugar)", "4 arquivos com cópia conferida".
String backupStateCount(BackupState state, int n) => switch (state) {
  BackupState.single => '${plural(n, 'arquivo', 'arquivos')} sem backup (só em 1 lugar)',
  BackupState.probable => '${plural(n, 'arquivo parece', 'arquivos parecem')} ter cópia (falta conferir)',
  BackupState.verified => '${plural(n, 'arquivo', 'arquivos')} com cópia conferida',
  BackupState.independent => '${plural(n, 'arquivo', 'arquivos')} com backup em outro disco',
  BackupState.unknown => '${plural(n, 'arquivo', 'arquivos')} que ainda não dá para saber',
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
