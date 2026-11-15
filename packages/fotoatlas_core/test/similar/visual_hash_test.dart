import 'dart:math';
import 'dart:typed_data';

import 'package:fotoatlas_core/src/similar/similar_grouping.dart';
import 'package:fotoatlas_core/src/similar/visual_hash.dart';
import 'package:fotoatlas_fixtures/fotoatlas_fixtures.dart';
import 'package:test/test.dart';

VisualHash hashOf(Uint8List jpeg) => visualHashFromBytes(jpeg)!;

void main() {
  group('impressão visual', () {
    test('hammingDistance conta bits, inclusive o de sinal', () {
      expect(hammingDistance(0, 0), 0);
      expect(hammingDistance(0, -1), 64);
      expect(hammingDistance(1 << 63, 0), 1);
      expect(hammingDistance(0xF0, 0x0F), 8);
    });

    test('a mesma cena reduzida, recomprimida ou mais clara: quase idênticas ou muito parecidas', () {
      for (var seed = 1; seed <= 30; seed++) {
        final original = hashOf(sceneJpeg(seed));
        for (final v in [SceneVariant.half, SceneVariant.lowQuality]) {
          expect(
            similarLevel(original, hashOf(sceneJpeg(seed, v))),
            SimilarLevel.nearIdentical,
            reason: 'cena $seed, $v',
          );
        }
        expect(
          similarLevel(original, hashOf(sceneJpeg(seed, SceneVariant.brighter)))?.atLeast(SimilarLevel.high),
          isTrue,
          reason: 'cena $seed mais clara',
        );
        expect(
          similarLevel(original, hashOf(sceneJpeg(seed, SceneVariant.burst))),
          isNotNull,
          reason: 'cena $seed em rajada',
        );
      }
    });

    test('cenas diferentes nunca viram sugestão', () {
      final hashes = [for (var seed = 1; seed <= 80; seed++) hashOf(sceneJpeg(seed))];
      for (var i = 0; i < hashes.length; i++) {
        for (var j = i + 1; j < hashes.length; j++) {
          expect(similarLevel(hashes[i], hashes[j]), isNull, reason: 'cenas ${i + 1} e ${j + 1}');
        }
      }
    });

    test('imagem lisa fica de fora (nem consigo mesma)', () {
      final black = hashOf(flatJpeg(5, 5, 5));
      final gray = hashOf(flatJpeg(128, 128, 128));
      expect(black.flat, isTrue);
      expect(gray.flat, isTrue);
      expect(similarLevel(black, gray), isNull);
      expect(similarLevel(black, black), isNull);
      expect(hashOf(sceneJpeg(1)).flat, isFalse);
    });

    test('dado que não é imagem: null, sem exceção', () {
      expect(visualHashFromBytes(Uint8List.fromList([1, 2, 3])), isNull);
      expect(visualHashFromFile(r'Z:\nao\existe.jpg'), isNull);
    });

    test('mesmo dia com data confiável reforça "talvez" para "muito parecidas"', () {
      // Duas impressões a 10 bits no pHash e perto no dHash.
      const a = VisualHash(0, 0);
      const b = VisualHash(0x3FF, 0x3);
      expect(similarLevel(a, b), SimilarLevel.maybe);
      expect(similarLevel(a, b, sameDay: true), SimilarLevel.high);
      // Longe no dHash: nem "talvez".
      expect(similarLevel(a, const VisualHash(0x3FF, 0xFFFFF)), isNull);
    });
  });

  group('busca e grupos', () {
    List<SimilarCandidate> randomWithNeighbors(int n, int seed) {
      final rnd = Random(seed);
      int r64() => (rnd.nextInt(1 << 32) << 32) | rnd.nextInt(1 << 32);
      final items = <SimilarCandidate>[];
      var id = 1;
      while (items.length < n) {
        final base = r64();
        final grad = r64();
        items.add(SimilarCandidate(id++, VisualHash(base, grad)));
        // Às vezes, vizinhos plantados a 1–14 bits.
        if (rnd.nextInt(5) == 0) {
          for (var k = rnd.nextInt(3) + 1; k > 0; k--) {
            var h = base;
            var g = grad;
            for (var b = rnd.nextInt(14) + 1; b > 0; b--) {
              h ^= 1 << rnd.nextInt(64);
            }
            for (var b = rnd.nextInt(20); b > 0; b--) {
              g ^= 1 << rnd.nextInt(64);
            }
            items.add(SimilarCandidate(id++, VisualHash(h, g)));
          }
        }
      }
      return items;
    }

    test('acha exatamente os mesmos pares que comparar todas com todas', () {
      final items = randomWithNeighbors(1500, 7);
      final fast = {for (final p in findSimilarPairs(items)) pairKey(p.a, p.b): p.level};
      final brute = <(int, int), SimilarLevel>{};
      for (var i = 0; i < items.length; i++) {
        for (var j = i + 1; j < items.length; j++) {
          final level = similarLevel(items[i].hash, items[j].hash);
          if (level != null) brute[pairKey(items[i].contentId, items[j].contentId)] = level;
        }
      }
      expect(brute, isNotEmpty);
      expect(fast, brute);
    });

    test('nível mínimo e pares descartados ficam de fora', () {
      const items = [
        SimilarCandidate(1, VisualHash(0, 0)),
        SimilarCandidate(2, VisualHash(0x3, 0)), // 2 bits: quase idênticas
        SimilarCandidate(3, VisualHash(0x3FF, 0)), // 10 bits: talvez
      ];
      expect(findSimilarPairs(items), hasLength(3));
      final strong = findSimilarPairs(items, minLevel: SimilarLevel.nearIdentical);
      expect([for (final p in strong) pairKey(p.a, p.b)], [(1, 2)]);
      final kept = findSimilarPairs(items, dismissed: {(1, 2)});
      expect([for (final p in kept) pairKey(p.a, p.b)], isNot(contains((1, 2))));
    });

    test('grupos: ligações fortes primeiro, nível do grupo é o da ligação mais fraca', () {
      const items = [
        SimilarCandidate(10, VisualHash(0, 0)),
        SimilarCandidate(11, VisualHash(0x1, 0)), // 1 bit de 10
        SimilarCandidate(12, VisualHash(0x7F, 0)), // 7 de 10: muito parecidas
        SimilarCandidate(20, VisualHash(-1, -1)), // outro grupo
        SimilarCandidate(21, VisualHash(-2, -1)),
        SimilarCandidate(30, VisualHash(0x5555555555555555, 0)), // sozinha
      ];
      final groups = groupSimilar(findSimilarPairs(items));
      expect(groups, hasLength(2));
      expect(groups[0].level, SimilarLevel.nearIdentical);
      expect(groups[0].contentIds.toSet(), {20, 21});
      expect(groups[1].level, SimilarLevel.high);
      expect(groups[1].contentIds.toSet(), {10, 11, 12});
      expect(groups[1].contentIds.first, anyOf(10, 11), reason: 'referência: a com mais ligações fortes');
      final onlyStrong = groupSimilar(findSimilarPairs(items, minLevel: SimilarLevel.nearIdentical));
      expect(
        [for (final g in onlyStrong) g.contentIds.toSet()],
        containsAll([
          {10, 11},
          {20, 21},
        ]),
      );
    });

    test('20 mil impressões: grupos em poucos segundos', () {
      final items = randomWithNeighbors(20000, 11);
      final sw = Stopwatch()..start();
      final groups = groupSimilar(findSimilarPairs(items));
      sw.stop();
      expect(groups, isNotEmpty);
      // Medido ~3 s (50 mil: ~8 s) sem AOT; o limite largo evita falso alarme num runner lento.
      expect(sw.elapsed, lessThan(const Duration(seconds: 30)), reason: '${sw.elapsedMilliseconds} ms');
      print('20 mil impressões: ${sw.elapsedMilliseconds} ms, ${groups.length} grupos');
    });
  });
}
