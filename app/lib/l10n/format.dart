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
