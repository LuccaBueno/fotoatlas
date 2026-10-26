/// Textos de domínio em PT-BR simples (spec §3.1). Nada de "hash", "MTP" ou
/// "WAL" aqui.
library;

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
