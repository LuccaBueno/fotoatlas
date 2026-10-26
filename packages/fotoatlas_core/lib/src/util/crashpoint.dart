import 'dart:io';

final Map<String, int> _hits = {};

/// Ponto instrumentado para testes de falha (ADR 0007).
///
/// Com `FOTOATLAS_CRASHPOINT=<nome>[:<n>]`, na n-ésima passagem (padrão 1)
/// imprime `CRASHPOINT <nome>` e bloqueia para sempre; o teste então mata o
/// processo com `Process.kill()`. Sem a variável, não faz nada.
void crashpoint(String name) {
  final spec = Platform.environment['FOTOATLAS_CRASHPOINT'];
  if (spec == null || spec.isEmpty) return;
  final parts = spec.split(':');
  if (parts.first != name) return;
  final target = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  final count = _hits[name] = (_hits[name] ?? 0) + 1;
  if (count != target) return;
  stdout.writeln('CRASHPOINT $name');
  // Bloqueia o isolate sem ceder: o processo só sai quando for morto.
  while (true) {
    sleep(const Duration(hours: 1));
  }
}
