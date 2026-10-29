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
    required this.originalDir,
    required this.mediaType,
    this.camera,
    this.sourceName,
  });

  /// Data da captura efetiva (com correções do catálogo); `null` = sem data.
  final int? year;
  final int? month;

  /// Dia do mês.
  final int? day;

  /// Pasta do arquivo na origem, relativa à raiz (`DCIM/Camera`).
  final String originalDir;
  final String mediaType;
  final String? camera;
  final String? sourceName;

  bool get dated => year != null && month != null;
}

/// Modelo de organização oferecido no assistente.
class FolderTemplate {
  const FolderTemplate(this.pattern, this.label);
  final String pattern;
  final String label;

  static const byMonth = FolderTemplate('{ano}/{ano}-{mes}', 'Por ano e mês (2024/2024-07)');
  static const byDay = FolderTemplate('{ano}/{ano}-{mes}-{dia}', 'Por ano e dia (2024/2024-07-13)');
  static const byTypeYear = FolderTemplate('{tipo}/{ano}', 'Por tipo e ano (Fotos/2024)');
  static const original = FolderTemplate('{original}', 'Mesma estrutura de pastas da origem');
  static const flat = FolderTemplate('', 'Tudo na mesma pasta');

  static const all = [byMonth, byDay, byTypeYear, original, flat];

  static FolderTemplate? byPattern(String pattern) => all.where((t) => t.pattern == pattern).firstOrNull;
}

/// Pasta (fora do modelo) dos itens sem data da captura (spec §12).
const String undatedFolder = 'Sem data confirmada';

const _dateVars = ['{ano}', '{mes}', '{dia}'];

/// Pasta relativa (com `/`) gerada por [pattern] para um item, já
/// sanitizada. Itens sem data vão para [undatedFolder] quando o modelo usa
/// data.
String renderFolder(String pattern, TemplateVars v) {
  if (pattern.trim().isEmpty) return '';
  if (!v.dated && _dateVars.any(pattern.contains)) {
    // Mantém o que não depende de data antes do primeiro campo de data (ex.: {tipo}).
    final head = pattern.split('/').takeWhile((s) => !_dateVars.any(s.contains)).join('/');
    final prefix = head.isEmpty ? '' : renderFolder(head, v);
    return prefix.isEmpty ? undatedFolder : '$prefix/$undatedFolder';
  }
  String two(int? n) => (n ?? 0).toString().padLeft(2, '0');
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
        .replaceAll('{ano}', '${v.year ?? ''}')
        .replaceAll('{mes}', two(v.month))
        .replaceAll('{dia}', two(v.day))
        .replaceAll('{tipo}', _typeFolder(v.mediaType))
        .replaceAll('{dispositivo}', v.camera ?? 'Dispositivo desconhecido')
        .replaceAll('{origem}', v.sourceName ?? 'Origem')
        .replaceAll('{original}', v.originalDir.replaceAll('/', ' '));
    if (text.trim().isEmpty) continue;
    segments.add(sanitizeName(text));
  }
  return segments.join('/');
}

String _typeFolder(String mediaType) => switch (mediaType) {
  'photo' || 'raw' => 'Fotos',
  'video' => 'Vídeos',
  _ => 'Outros',
};
