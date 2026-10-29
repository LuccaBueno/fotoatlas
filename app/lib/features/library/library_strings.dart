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

/// "14:02–17:10", ou só "09:00" quando começa e termina no mesmo minuto.
String momentTimeRange(MomentView m) {
  final s = m.startLocal, e = m.endLocal;
  if (s == null) return '';
  if (e == null ||
      (e.year == s.year && e.month == s.month && e.day == s.day && e.hour == s.hour && e.minute == s.minute)) {
    return formatClock(s, seconds: false);
  }
  return '${formatClock(s, seconds: false)}–${formatClock(e, seconds: false)}';
}

const _weekdayName = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];

String _part(DateTime w) => switch (w.hour) {
  < 6 => 'de madrugada',
  < 12 => 'de manhã',
  < 18 => 'à tarde',
  _ => 'à noite',
};

/// Nome descritivo de um momento sem nome: "Sábado de manhã", "Sábado, da
/// manhã à tarde", "Sábado à noite até domingo".
String momentAutoName(MomentView m) {
  final s = m.startLocal, e = m.endLocal;
  if (s == null) return 'Momento';
  final day = _weekdayName[s.weekday - 1];
  if (e == null || _part(e) == _part(s) && e.day == s.day) return '$day ${_part(s)}';
  if (e.day != s.day || e.month != s.month || e.year != s.year) {
    return '$day ${_part(s)} até ${_weekdayName[e.weekday - 1].toLowerCase()}';
  }
  String bare(String p) => p.replaceFirst(RegExp(r'^(de |à )'), '');
  return '$day, da ${bare(_part(s))} à ${bare(_part(e))}'
      .replaceAll('da madrugada', 'de madrugada')
      .replaceAll('à madrugada', 'de madrugada');
}

/// Nome do momento: o dado pelo usuário, ou o descritivo com o dia
/// ("Sábado de manhã · 4 de maio de 2024") — para listas sem o cabeçalho do dia.
String momentTitle(MomentView m) {
  final name = m.name;
  if (name != null && name.isNotEmpty) return name;
  final s = m.startLocal;
  if (s == null) return 'Momento';
  return '${momentAutoName(m)} · ${s.day} de ${monthName(s.month)} de ${s.year}';
}

/// "4 itens · 14:02–17:10" (ou "1 item · 09:00").
String momentSubtitle(MomentView m) {
  final range = momentTimeRange(m);
  final count = plural(m.itemCount, 'item', 'itens');
  return range.isEmpty ? count : '$count · $range';
}
