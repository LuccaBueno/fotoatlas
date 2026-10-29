import 'package:flutter/material.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../l10n/format.dart';

/// De onde veio a hora, em português simples.
String dateSourceLabel(DateSource s) => switch (s) {
  DateSource.manual => 'definida por você',
  DateSource.exifOriginal => 'da câmera (dados da foto)',
  DateSource.videoInternal => 'gravada no vídeo',
  DateSource.filename => 'do nome do arquivo',
  DateSource.filesystem => 'data do arquivo no disco',
  DateSource.none => 'sem data',
};

String confidenceLabel(DateConfidence c) => switch (c) {
  DateConfidence.high => 'Hora confiável',
  DateConfidence.medium => 'Hora provável',
  DateConfidence.low => 'Hora incerta',
  DateConfidence.none => 'Sem data',
};

IconData confidenceIcon(DateConfidence c) => switch (c) {
  DateConfidence.high => Icons.verified_outlined,
  DateConfidence.medium => Icons.schedule,
  DateConfidence.low => Icons.help_outline,
  DateConfidence.none => Icons.event_busy_outlined,
};

const weekdayShort = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const weekdayLong = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

String mediaTypeLabel(String t) => switch (t) {
  'photo' => 'Fotos',
  'raw' => 'RAW',
  'video' => 'Vídeos',
  _ => 'Outros',
};

/// "Canon EOS X" a partir de 'fabricante\u0001modelo'.
String cameraLabel(String key) {
  final parts = key.split('\u0001');
  final make = parts[0], model = parts.length > 1 ? parts[1] : '';
  if (model.isEmpty) return make.isEmpty ? 'Desconhecido' : make;
  return make.isEmpty || model.toLowerCase().startsWith(make.toLowerCase()) ? model : '$make $model';
}

/// Nome do momento: o dado pelo usuário, ou o dia e o horário.
String momentTitle(MomentView m) {
  final name = m.name;
  if (name != null && name.isNotEmpty) return name;
  final s = m.startLocal, e = m.endLocal;
  if (s == null) return 'Momento';
  final range = e == null || (e.hour == s.hour && e.minute == s.minute)
      ? formatClock(s, seconds: false)
      : '${formatClock(s, seconds: false)}–${formatClock(e, seconds: false)}';
  return '${formatLongDay(s)} · $range';
}

/// "4 itens · 14:02–14:05" para a linha do momento.
String momentSubtitle(MomentView m) {
  final s = m.startLocal, e = m.endLocal;
  final count = plural(m.itemCount, 'item', 'itens');
  if (s == null) return count;
  if (m.name == null) return count;
  final range = e == null
      ? formatClock(s, seconds: false)
      : '${formatClock(s, seconds: false)}–${formatClock(e, seconds: false)}';
  return '$count · $range';
}
