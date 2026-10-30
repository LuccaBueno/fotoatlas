/// Formatação em PT-BR sem dependências (números, tamanhos e datas).
library;

/// 12345 → "12.345".
String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

/// 48955555 → "46,7 MB".
String formatBytes(int? bytes) {
  if (bytes == null) return '—';
  const units = ['bytes', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  if (unit == 0) return '${formatInt(bytes)} ${bytes == 1 ? 'byte' : 'bytes'}';
  final text = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '${text.replaceAll('.', ',')} ${units[unit]}';
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Data e hora local: "26/10/2026 14:05".
String formatDateTime(DateTime value) {
  final t = value.toLocal();
  return '${_two(t.day)}/${_two(t.month)}/${t.year} ${_two(t.hour)}:${_two(t.minute)}';
}

/// Data e hora a partir de ms Unix UTC (convenção do catálogo).
String formatEpochMs(int ms) => formatDateTime(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));

/// "1 arquivo" / "2 arquivos".
String plural(int n, String singular, String pluralForm) => '${formatInt(n)} ${n == 1 ? singular : pluralForm}';

/// Duração aproximada: "menos de 1 min", "12 min", "2 h 5 min".
String formatDuration(Duration d) {
  final minutes = (d.inSeconds / 60).ceil();
  if (minutes < 1) return 'menos de 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

const _weekdays = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
const _months = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

/// "maio" (1 = janeiro).
String monthName(int month) => _months[month - 1];

/// "Maio de 2024".
String formatMonthYear(int year, int month) {
  final m = monthName(month);
  return '${m[0].toUpperCase()}${m.substring(1)} de $year';
}

/// Hora "de relógio" (sem fuso) guardada num DateTime UTC: os campos valem como estão.
/// "Quarta-feira, 1 de maio de 2024".
String formatLongDay(DateTime wall) {
  final w = _weekdays[wall.weekday - 1];
  return '${w[0].toUpperCase()}${w.substring(1)}, ${wall.day} de ${monthName(wall.month)} de ${wall.year}';
}

/// "14:03:12" (+ ",450" com subsegundos se [subSeconds]).
String formatClock(DateTime wall, {bool seconds = true, bool subSeconds = false}) {
  final base = seconds
      ? '${_two(wall.hour)}:${_two(wall.minute)}:${_two(wall.second)}'
      : '${_two(wall.hour)}:${_two(wall.minute)}';
  return subSeconds && wall.millisecond != 0 ? '$base,${wall.millisecond.toString().padLeft(3, '0')}' : base;
}

/// "01/05/2024 14:03:12".
String formatWallDateTime(DateTime wall, {bool seconds = true}) =>
    '${_two(wall.day)}/${_two(wall.month)}/${wall.year} ${formatClock(wall, seconds: seconds)}';

/// "UTC−3", "UTC+2", "UTC+5:30".
String formatOffset(int? minutes) {
  if (minutes == null) return '';
  final sign = minutes < 0 ? '−' : '+';
  final m = minutes.abs();
  return 'UTC$sign${m ~/ 60}${m % 60 == 0 ? '' : ':${_two(m % 60)}'}';
}

/// Duração de vídeo: "0:42", "12:05", "1:02:03".
String formatVideoLength(int ms) {
  final s = ms ~/ 1000;
  final h = s ~/ 3600, m = (s % 3600) ~/ 60, sec = s % 60;
  return h > 0 ? '$h:${_two(m)}:${_two(sec)}' : '$m:${_two(sec)}';
}

/// Deslocamento para a interface: "+1 h", "−3 min 20 s".
String formatShift(Duration d) {
  if (d == Duration.zero) return '0 s';
  final sign = d.isNegative ? '−' : '+';
  var rest = d.abs().inSeconds;
  final days = rest ~/ 86400;
  rest %= 86400;
  final h = rest ~/ 3600;
  rest %= 3600;
  final m = rest ~/ 60, s = rest % 60;
  return '$sign${[if (days > 0) '$days d', if (h > 0) '$h h', if (m > 0) '$m min', if (s > 0) '$s s'].join(' ')}';
}

/// Há quanto tempo: "hoje", "ontem", "há 5 dias", "há 3 meses", "há 2 anos".
String formatAgo(DateTime value, {DateTime? now}) {
  final days = (now ?? DateTime.now()).difference(value).inDays;
  if (days <= 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 60) return 'há $days dias';
  if (days < 730) return 'há ${days ~/ 30} meses';
  return 'há ${days ~/ 365} anos';
}
