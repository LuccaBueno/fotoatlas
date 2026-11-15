import 'dart:typed_data';

import 'visual_hash.dart';

/// Nível de confiança de uma sugestão de fotos parecidas (só sugestão: nada
/// é feito sozinho).
enum SimilarLevel {
  /// Talvez parecidas (mesma cena, enquadramento ou edição diferentes).
  maybe,

  /// Muito parecidas (outra compressão, tamanho ou pequeno corte).
  high,

  /// Quase idênticas (a mesma foto em outro tamanho ou qualidade).
  nearIdentical;

  bool atLeast(SimilarLevel other) => index >= other.index;
}

/// Limites de distância (bits diferentes em 64) do pHash de cada nível.
/// Calibrados com as cenas sintéticas de `test/similar/`: a mesma foto
/// reduzida, recomprimida ou mais clara fica em até 6; rajada até 10; cenas
/// diferentes a partir de 10, quase sempre com o dHash acima de 20.
const nearIdenticalMax = 4;
const highMax = 8;
const maybeMax = 12;

/// "Talvez" só com o dHash também perto (afasta cenas diferentes).
const maybeGradientMax = 18;

/// Nível de duas impressões; `null` = não parecidas. [sameDay]: as duas têm
/// data confiável no mesmo dia — reforça "talvez" para "muito parecidas".
SimilarLevel? similarLevel(VisualHash a, VisualHash b, {bool sameDay = false}) {
  if (a.flat || b.flat) return null;
  final dp = hammingDistance(a.perceptual, b.perceptual);
  if (dp <= nearIdenticalMax) return SimilarLevel.nearIdentical;
  if (dp <= highMax) return SimilarLevel.high;
  if (dp <= maybeMax && hammingDistance(a.gradient, b.gradient) <= maybeGradientMax) {
    return sameDay ? SimilarLevel.high : SimilarLevel.maybe;
  }
  return null;
}

/// Uma foto (conteúdo) com a impressão visual e o dia da data confiável.
class SimilarCandidate {
  const SimilarCandidate(this.contentId, this.hash, {this.day});
  final int contentId;
  final VisualHash hash;

  /// 'AAAA-MM-DD' da data efetiva, só quando confiável.
  final String? day;
}

/// Um par sugerido.
class SimilarPair {
  const SimilarPair(this.a, this.b, this.level, this.distance);
  final int a;
  final int b;
  final SimilarLevel level;

  /// Distância do pHash (0 = impressões iguais).
  final int distance;
}

/// Um grupo de fotos parecidas.
class SimilarGroup {
  const SimilarGroup(this.contentIds, this.level, this.pairs);

  /// A primeira é a referência da comparação lado a lado.
  final List<int> contentIds;

  /// O nível mais fraco entre as ligações que formaram o grupo.
  final SimilarLevel level;
  final List<SimilarPair> pairs;
}

/// Chave de um par (menor id primeiro).
(int, int) pairKey(int a, int b) => a < b ? (a, b) : (b, a);

/// Pares parecidos entre [items], sem os descartados pelo usuário
/// ([dismissed], "Não são parecidas"). Busca por partes da impressão
/// (multi-index hashing): uma distância ≤ 12 em 64 bits deixa pelo menos uma
/// das 4 partes de 16 bits com distância ≤ 3, então só esses vizinhos são
/// comparados — dezenas de milhares de fotos em segundos, sem comparar todas
/// com todas.
List<SimilarPair> findSimilarPairs(
  List<SimilarCandidate> items, {
  Set<(int, int)> dismissed = const {},
  SimilarLevel minLevel = SimilarLevel.maybe,
}) {
  final usable = [
    for (final i in items)
      if (!i.hash.flat) i,
  ];
  final n = usable.length;
  final hashes = Int64List(n);
  for (var k = 0; k < n; k++) {
    hashes[k] = usable[k].hash.perceptual;
  }
  // Para cada parte de 16 bits, os itens agrupados pelo valor da parte
  // (start[v]..start[v+1] em order): consulta por índice, sem mapa.
  final starts = <Int32List>[];
  final orders = <Int32List>[];
  for (var part = 0; part < 4; part++) {
    final shift = part * 16;
    final start = Int32List(65537);
    for (var k = 0; k < n; k++) {
      start[((hashes[k] >>> shift) & 0xFFFF) + 1]++;
    }
    for (var v = 0; v < 65536; v++) {
      start[v + 1] += start[v];
    }
    final fill = Int32List.fromList(start);
    final order = Int32List(n);
    for (var k = 0; k < n; k++) {
      order[fill[(hashes[k] >>> shift) & 0xFFFF]++] = k;
    }
    starts.add(start);
    orders.add(order);
  }
  final masks = _masks;
  final seenBy = Int32List(n)..fillRange(0, n, -1);
  final pairs = <SimilarPair>[];
  for (var k = 0; k < n; k++) {
    final h = hashes[k];
    for (var part = 0; part < 4; part++) {
      final key = (h >>> (part * 16)) & 0xFFFF;
      final start = starts[part];
      final order = orders[part];
      for (final m in masks) {
        final v = key ^ m;
        for (var i = start[v]; i < start[v + 1]; i++) {
          final j = order[i];
          if (j <= k || seenBy[j] == k) continue;
          seenBy[j] = k;
          if (hammingDistance(h, hashes[j]) > maybeMax) continue;
          final a = usable[k];
          final b = usable[j];
          final sameDay = a.day != null && a.day == b.day;
          final level = similarLevel(a.hash, b.hash, sameDay: sameDay);
          if (level == null || !level.atLeast(minLevel)) continue;
          if (dismissed.contains(pairKey(a.contentId, b.contentId))) continue;
          pairs.add(SimilarPair(a.contentId, b.contentId, level, hammingDistance(h, hashes[j])));
        }
      }
    }
  }
  return pairs;
}

/// Máscaras de 16 bits com até 3 bits ligados (697).
final List<int> _masks = () {
  final masks = <int>[0];
  for (var i = 0; i < 16; i++) {
    masks.add(1 << i);
    for (var j = i + 1; j < 16; j++) {
      masks.add((1 << i) | (1 << j));
      for (var k = j + 1; k < 16; k++) {
        masks.add((1 << i) | (1 << j) | (1 << k));
      }
    }
  }
  return masks;
}();

/// Junta os pares em grupos (as ligações mais fortes primeiro). O nível do
/// grupo é o da ligação mais fraca que ele precisou. Grupos maiores primeiro
/// dentro do mesmo nível; a referência de cada grupo é a foto com mais
/// ligações fortes.
List<SimilarGroup> groupSimilar(List<SimilarPair> pairs) {
  final sorted = [...pairs]
    ..sort((x, y) {
      final byLevel = y.level.index.compareTo(x.level.index);
      return byLevel != 0 ? byLevel : x.distance.compareTo(y.distance);
    });
  final parent = <int, int>{};
  int find(int x) {
    var r = x;
    while (parent[r] != r) {
      r = parent[r]!;
    }
    var c = x;
    while (parent[c] != r) {
      final next = parent[c]!;
      parent[c] = r;
      c = next;
    }
    return r;
  }

  final weakest = <int, SimilarLevel>{};
  for (final pr in sorted) {
    parent.putIfAbsent(pr.a, () => pr.a);
    parent.putIfAbsent(pr.b, () => pr.b);
    final ra = find(pr.a);
    final rb = find(pr.b);
    if (ra == rb) continue;
    final la = weakest.remove(ra);
    final lb = weakest.remove(rb);
    parent[rb] = ra;
    var level = pr.level;
    for (final l in [la, lb]) {
      if (l != null && l.index < level.index) level = l;
    }
    weakest[ra] = level;
  }
  final members = <int, List<int>>{};
  for (final id in parent.keys) {
    (members[find(id)] ??= []).add(id);
  }
  final byGroup = <int, List<SimilarPair>>{};
  for (final pr in pairs) {
    (byGroup[find(pr.a)] ??= []).add(pr);
  }
  final groups = <SimilarGroup>[];
  for (final MapEntry(key: root, value: ids) in members.entries) {
    final groupPairs = byGroup[root] ?? const [];
    final score = <int, int>{};
    for (final pr in groupPairs) {
      final w = 1 << (pr.level.index * 4);
      score[pr.a] = (score[pr.a] ?? 0) + w;
      score[pr.b] = (score[pr.b] ?? 0) + w;
    }
    ids.sort((x, y) {
      final s = (score[y] ?? 0).compareTo(score[x] ?? 0);
      return s != 0 ? s : x.compareTo(y);
    });
    groups.add(SimilarGroup(ids, weakest[root]!, groupPairs));
  }
  groups.sort((x, y) {
    final byLevel = y.level.index.compareTo(x.level.index);
    if (byLevel != 0) return byLevel;
    final bySize = y.contentIds.length.compareTo(x.contentIds.length);
    return bySize != 0 ? bySize : x.contentIds.first.compareTo(y.contentIds.first);
  });
  return groups;
}
