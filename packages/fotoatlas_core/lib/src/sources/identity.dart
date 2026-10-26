import 'volumes.dart';

/// Identidade gravada de uma fonte de volume (ou pasta dentro de um volume).
class SourceIdentity {
  const SourceIdentity({
    this.volumeGuid,
    this.volumeSerial,
    this.volumeLabel,
    this.fileSystem,
    this.volumeSizeBytes,
    this.reliableDiskSerial,
  });

  final String? volumeGuid;
  final int? volumeSerial;
  final String? volumeLabel;
  final String? fileSystem;
  final int? volumeSizeBytes;

  /// Serial do disco físico, só quando a identidade dele é `reliable`.
  final String? reliableDiskSerial;
}

/// Resultado do reconhecimento de uma fonte entre os volumes conectados.
sealed class MatchResult {
  const MatchResult();
}

/// Reconhecida sem ambiguidade.
class Matched extends MatchResult {
  const Matched(this.volume, this.score);
  final VolumeInfo volume;
  final int score;
}

/// Mais de um candidato, ou pontuação insuficiente: perguntar ao usuário.
class Ambiguous extends MatchResult {
  const Ambiguous(this.candidates);
  final List<(VolumeInfo, int)> candidates;
}

/// Nenhum volume conectado parece ser esta fonte (regra 9: não é "vazia").
class NotConnected extends MatchResult {
  const NotConnected();
}

/// Pontuação de identidade (ADR 0009, `docs/arquitetura.md` §3.5).
abstract final class IdentityScoring {
  static const int autoThreshold = 60;
  static const int askThreshold = 30;
  static const int decisiveMargin = 40;

  static int score(SourceIdentity s, VolumeInfo v) {
    var score = 0;
    if (s.volumeGuid != null && _sameGuid(s.volumeGuid!, v.guidPath)) score += 50;
    if (s.volumeSerial != null && v.serial != null) {
      score += s.volumeSerial == v.serial ? 30 : -40;
    }
    final disk = v.primaryDisk;
    if (s.reliableDiskSerial != null && disk != null && disk.isReliable && disk.serial == s.reliableDiskSerial) {
      score += 15;
    }
    if (s.volumeLabel != null && s.volumeLabel!.isNotEmpty && s.volumeLabel == v.label) score += 5;
    if (s.fileSystem != null && s.fileSystem == v.fileSystem) score += 5;
    if (s.volumeSizeBytes != null && s.volumeSizeBytes == v.totalBytes) score += 5;
    return score;
  }

  static MatchResult match(SourceIdentity s, List<VolumeInfo> volumes) {
    final scored = [
      for (final v in volumes)
        if (!v.isSystem) (v, score(s, v)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    final strong = scored.where((e) => e.$2 >= autoThreshold).toList();
    if (strong.length == 1) return Matched(strong.single.$1, strong.single.$2);
    // Vários fortes (ex.: disco clonado): o melhor só vence com folga clara,
    // como o GUID já confirmado pelo usuário.
    if (strong.length > 1 && strong[0].$2 - strong[1].$2 >= decisiveMargin) {
      return Matched(strong[0].$1, strong[0].$2);
    }
    final candidates = scored.where((e) => e.$2 >= askThreshold).toList();
    if (candidates.isNotEmpty) return Ambiguous(candidates);
    return const NotConnected();
  }

  static bool _sameGuid(String a, String b) => _norm(a) == _norm(b);

  static String _norm(String guidPath) {
    var g = guidPath.toLowerCase();
    if (g.endsWith(r'\')) g = g.substring(0, g.length - 1);
    return g.replaceFirst(r'\\.\', r'\\?\');
  }
}
