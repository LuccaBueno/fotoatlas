/// Classificação por extensão (minúscula, sem ponto). Os metadados reais vêm
/// na Fase 4; aqui só serve para contagens e prioridades.
abstract final class MediaTypes {
  static const photo = {
    'jpg',
    'jpeg',
    'jpe',
    'heic',
    'heif',
    'hif',
    'png',
    'webp',
    'gif',
    'bmp',
    'tif',
    'tiff',
    'avif',
    'jxl',
  };
  static const raw = {
    'dng',
    'cr2',
    'cr3',
    'crw',
    'nef',
    'nrw',
    'arw',
    'srf',
    'sr2',
    'orf',
    'rw2',
    'raf',
    'pef',
    'srw',
    'x3f',
    '3fr',
    'iiq',
    'erf',
    'mrw',
    'rwl',
  };
  static const video = {
    'mp4',
    'mov',
    'm4v',
    'avi',
    'mkv',
    '3gp',
    '3g2',
    'mts',
    'm2ts',
    'wmv',
    'mpg',
    'mpeg',
    'webm',
    'flv',
    'insv',
    'lrv',
  };
  static const sidecar = {'xmp', 'aae', 'thm'};

  /// Foto, RAW ou vídeo.
  static final Set<String> media = {...photo, ...raw, ...video};

  static String mediaTypeOf(String ext) {
    if (photo.contains(ext)) return 'photo';
    if (raw.contains(ext)) return 'raw';
    if (video.contains(ext)) return 'video';
    if (sidecar.contains(ext)) return 'sidecar';
    return 'other';
  }

  /// Lista SQL `('jpg','jpeg',…)` para consultas de contagem.
  static String sqlList(Iterable<String> exts) => '(${exts.map((e) => "'$e'").join(',')})';
}
