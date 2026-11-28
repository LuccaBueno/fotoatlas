import 'package:test/test.dart';

import 'lag_reference.dart';

/// A conta que separa o atraso do app das paradas da máquina não pode
/// descontar nada além do trecho em que a referência também parou.
void main() {
  Stall s(int endMs, int lagMs) => (endUs: endMs * 1000, lagMs: lagMs);

  test('sem referência, o atraso conta inteiro', () {
    expect(maxExcessMs([s(1000, 187), s(5000, 16)], const []), 187);
    expect(maxExcessMs(const [], [s(1000, 300)]), 0);
  });

  test('a máquina parou junto: só a sobra é do app', () {
    // App parado de 813 a 1000 ms; referência parada de 820 a 990 ms.
    expect(maxExcessMs([s(1000, 187)], [s(990, 170)]), 17);
  });

  test('parada da referência em outro momento não desconta nada', () {
    expect(maxExcessMs([s(1000, 187)], [s(3000, 187)]), 187);
    // Encostada mas fora do intervalo.
    expect(maxExcessMs([s(1000, 187)], [s(813, 50)]), 187);
  });

  test('só a parte que se sobrepõe desconta; sobreposições não contam duas vezes', () {
    // App de 800 a 1000 (200 ms); referência de 900 a 1100: só 100 ms coincidem.
    expect(maxExcessMs([s(1000, 200)], [s(1100, 200)]), 100);
    // Duas paradas da referência que se cruzam (850–950 e 900–960): 110 ms.
    expect(maxExcessMs([s(1000, 200)], [s(950, 100), s(960, 60)]), 90);
  });

  test('vale a maior sobra entre as paradas do app', () {
    expect(maxExcessMs([s(1000, 187), s(4000, 120)], [s(1000, 187)]), 120);
  });
}
