/// Nomes e pastas do destino: sanitização para o Windows (lacuna L3) e
/// modelos de organização (spec §12, subconjunto da Fase 5).
library;

const _reserved = {
  'CON', 'PRN', 'AUX', 'NUL', //
  'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
  'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
};

/// Limite de um componente de caminho no NTFS/FAT32/exFAT (unidades UTF-16).
const int maxNameLength = 255;

/// Nome seguro para o Windows, de forma determinística (a prévia mostra o
/// resultado e o diário guarda o original):
/// - `< > : " / \ | ? *` e caracteres de controle viram `_`;
/// - pontos e espaços no fim saem (o Windows os ignora e isso confunde);
/// - nomes reservados (`CON`, `NUL`, `COM1`… com qualquer extensão) ganham `_` na frente;
/// - nomes longos são encurtados preservando a extensão.
String sanitizeName(String name, {String fallback = '_'}) {
  final buffer = StringBuffer();
  for (final unit in name.runes) {
    final forbidden = unit < 0x20 || '<>:"/\\|?*'.contains(String.fromCharCode(unit));
    buffer.write(forbidden ? '_' : String.fromCharCode(unit));
  }
  var out = buffer.toString().replaceAll(RegExp(r'[. ]+$'), '');
  if (out.trim().isEmpty) out = fallback;
  final dot = out.indexOf('.');
  final stem = dot < 0 ? out : out.substring(0, dot);
  if (_reserved.contains(stem.trimRight().toUpperCase())) out = '_$out';
  if (out.length > maxNameLength) {
    final ext = _extensionOf(out);
    final keep = ext.length < 40 ? ext : '';
    out = out.substring(0, maxNameLength - keep.length) + keep;
    out = out.replaceAll(RegExp(r'[. ]+$'), '');
  }
  return out;
}

String _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot);
}

/// `IMG.jpg` → `IMG_1.jpg`, `IMG_2.jpg`… (política de conflito "sufixo").
String withSuffix(String name, int n) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0) return '${name}_$n';
  return '${name.substring(0, dot)}_$n${name.substring(dot)}';
}

/// Informações de um item usadas pelos modelos.
class TemplateVars {
  const TemplateVars({
    this.year,
    this.month,
    this.day,
    this.hour,
    this.minute,
    this.second,
    required this.originalDir,
    required this.mediaType,
    this.camera,
    this.sourceName,
    this.momentStart,
    this.momentName,
  });

  /// Data da captura efetiva (com correções do catálogo); `null` = sem data.
  final int? year;
  final int? month;

  /// Dia do mês.
  final int? day;

  /// Hora local da captura (com as correções do catálogo).
  final int? hour;
  final int? minute;
  final int? second;

  /// Pasta do arquivo na origem, relativa à raiz (`DCIM/Camera`).
  final String originalDir;
  final String mediaType;
  final String? camera;
  final String? sourceName;

  /// Início do momento do item (hora local); `null` = fora de momentos
  /// ("Hora a confirmar").
  final DateTime? momentStart;

  /// Nome dado pelo usuário ao momento (`null` = sem nome).
  final String? momentName;

  bool get dated => year != null && month != null;
  bool get inMoment => momentStart != null;
}

/// Modelo de organização oferecido nos assistentes.
class FolderTemplate {
  const FolderTemplate(this.pattern, this.label);
  final String pattern;
  final String label;

  static const byMonth = FolderTemplate('{ano}/{ano}-{mes}', 'Por ano e mês (2024/2024-07)');
  static const byDay = FolderTemplate('{ano}/{ano}-{mes}-{dia}', 'Por ano e dia (2024/2024-07-13)');
  static const byMoment = FolderTemplate(
    '{ano}/{ano}-{mes}-{dia} {momento}',
    'Por ano e momento (2024/2024-07-13 Aniversário da Ana)',
  );
  static const byTypeYear = FolderTemplate('{tipo}/{ano}', 'Por tipo e ano (Fotos/2024)');
  static const byDeviceYear = FolderTemplate('{ano}/{dispositivo}', 'Por ano e câmera (2024/Pixel 7)');
  static const original = FolderTemplate('{original}', 'Mesma estrutura de pastas da origem');
  static const flat = FolderTemplate('', 'Tudo na mesma pasta');

  static const all = [byMonth, byDay, byMoment, byTypeYear, byDeviceYear, original, flat];

  static FolderTemplate? byPattern(String pattern) => all.where((t) => t.pattern == pattern).firstOrNull;
}

/// Pasta (fora do modelo) dos itens sem data da captura ou fora de momentos
/// (spec §12). Configurável nos assistentes.
const String undatedFolder = 'Sem data confirmada';

/// Campos que dependem da data e hora da captura.
const _dateVars = ['{ano}', '{mes}', '{dia}', '{hora}', '{minuto}', '{segundo}'];

bool _usesDate(String s) => _dateVars.any(s.contains) || s.contains('{momento}');

/// O modelo usa algum campo de data, hora ou momento.
bool templateUsesDate(String pattern) => _usesDate(pattern);

/// O modelo agrupa por momento (`{momento}`).
bool templateUsesMoment(String pattern) => pattern.contains('{momento}');

/// Pasta relativa (com `/`) gerada por [pattern] para um item, já
/// sanitizada.
///
/// - Sem data, ou fora de momentos quando o modelo usa `{momento}`, o item vai
///   para [toConfirm] (mantendo o que vem antes do primeiro campo de data, ex.:
///   `{tipo}`).
/// - Com `{momento}`, os campos de data e hora vêm do **início do momento**:
///   um momento que atravessa a meia-noite fica numa pasta só.
/// - Momento sem nome: `{momento}` vira o horário de início (`14h03`), o que dá
///   `2024-07-13 14h03` no modelo por momento.
String renderFolder(String pattern, TemplateVars v, {String toConfirm = undatedFolder}) {
  if (pattern.trim().isEmpty) return '';
  final byMoment = templateUsesMoment(pattern);
  final missing = byMoment ? !v.inMoment : !v.dated && _usesDate(pattern);
  if (missing) {
    final head = pattern.split('/').takeWhile((s) => !_usesDate(s)).join('/');
    final prefix = head.isEmpty ? '' : renderFolder(head, v, toConfirm: toConfirm);
    final folder = _cleanPath(toConfirm);
    final tail = folder.isEmpty ? undatedFolder : folder;
    return prefix.isEmpty ? tail : '$prefix/$tail';
  }
  final m = v.momentStart;
  final (year, month, day, hour, minute, second) = byMoment && m != null
      ? (m.year, m.month, m.day, m.hour, m.minute, m.second)
      : (v.year, v.month, v.day, v.hour, v.minute, v.second);
  String two(int? n) => (n ?? 0).toString().padLeft(2, '0');
  final momentText = switch (v.momentName?.trim()) {
    final name? when name.isNotEmpty => name,
    _ => m == null ? '' : '${two(m.hour)}h${two(m.minute)}',
  };
  final segments = <String>[];
  for (final raw in pattern.split('/')) {
    if (raw.trim().isEmpty) continue;
    if (raw == '{original}') {
      segments.addAll([
        for (final s in v.originalDir.split('/'))
          if (s.isNotEmpty) sanitizeName(s),
      ]);
      continue;
    }
    final text = raw
        .replaceAll('{ano}', '${year ?? ''}')
        .replaceAll('{mes}', two(month))
        .replaceAll('{dia}', two(day))
        .replaceAll('{hora}', two(hour))
        .replaceAll('{minuto}', two(minute))
        .replaceAll('{segundo}', two(second))
        // O nome do momento pode ter "/" ou "\": não vira subpasta.
        .replaceAll('{momento}', momentText.replaceAll(RegExp(r'[\/]'), '_'))
        .replaceAll('{tipo}', _typeFolder(v.mediaType))
        .replaceAll('{dispositivo}', v.camera ?? 'Dispositivo desconhecido')
        .replaceAll('{origem}', v.sourceName ?? 'Origem')
        .replaceAll('{original}', v.originalDir.replaceAll('/', ' '));
    if (text.trim().isEmpty) continue;
    segments.add(sanitizeName(text.replaceAll(RegExp(r'\s+'), ' ').trim()));
  }
  return segments.join('/');
}

/// Pasta digitada pela pessoa (`Backup\Fotos`) → `Backup/Fotos`, sanitizada.
String _cleanPath(String folder) => [
  for (final s in folder.replaceAll(r'\', '/').split('/'))
    if (s.trim().isNotEmpty && s != '.' && s != '..') sanitizeName(s.trim()),
].join('/');

/// Versão pública de [_cleanPath] (assistentes e planejadores).
String cleanFolder(String folder) => _cleanPath(folder);

String _typeFolder(String mediaType) => switch (mediaType) {
  'photo' || 'raw' => 'Fotos',
  'video' => 'Vídeos',
  _ => 'Outros',
};
