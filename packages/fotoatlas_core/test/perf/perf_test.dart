@Tags(['slow', 'perf'])
library;

import 'package:test/test.dart';

import 'coverage_100k.dart' as coverage_100k;
import 'scan_50k.dart' as scan_50k;

/// Testes de desempenho num arquivo só, para rodarem **um depois do outro**:
/// em arquivos separados o `dart test` os rodava em paralelo, e a geração
/// dos 50 mil arquivos (disco e CPU) atrasava a medição da cobertura de
/// 100 mil (1,5 s sozinha; até 5,4 s competindo, acima do limite de 5 s).
void main() {
  group('scan de 50 mil arquivos', scan_50k.main);
  group('cobertura de 100 mil arquivos', coverage_100k.main);
}
