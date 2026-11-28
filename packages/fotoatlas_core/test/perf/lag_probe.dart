import 'dart:async';
import 'dart:io';

/// Referência do teste de desempenho do scan (ver `lag_reference.dart`): o
/// mesmo relógio de 10 ms, num processo que não faz mais nada. Escreve
/// `parada <fim em µs> <atraso em ms>` para cada atraso ≥ limite e
/// `fim <ticks>` quando o stdin fecha.
void main(List<String> args) {
  final threshold = int.parse(args.first);
  final watch = Stopwatch()..start();
  var expected = 10, ticks = 0;
  final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
    final lag = watch.elapsedMilliseconds - expected;
    if (lag >= threshold) stdout.writeln('parada ${DateTime.now().microsecondsSinceEpoch} $lag');
    expected = watch.elapsedMilliseconds + 10;
    ticks++;
  });
  stdin.listen(
    (_) {},
    onDone: () async {
      timer.cancel();
      stdout.writeln('fim $ticks');
      await stdout.flush();
      exit(0);
    },
  );
  stdout.writeln('pronto');
}
