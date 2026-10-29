import 'dart:io';

final Map<String, int> _hits = {};

/// Ponto instrumentado para testes de falha (ADR 0007).
///
/// Com `FOTOATLAS_CRASHPOINT=<nome>[:<n>]`, na n-ésima passagem (padrão 1)
/// imprime `CRASHPOINT <nome>` e bloqueia para sempre; o teste então mata o
/// processo com `Process.kill()`. Sem a variável, não faz nada.
void crashpoint(String name) {
  if (crashpointArmed(name)) crashpointNow(name);
}

/// Conta uma passagem por [name] e diz se é a escolhida pela variável. Para
/// pontos que ficam em outro isolate (a contagem fica no principal, que passa
/// a decisão adiante).
bool crashpointArmed(String name) {
  final spec = Platform.environment['FOTOATLAS_CRASHPOINT'];
  if (spec == null || spec.isEmpty) return false;
  final parts = spec.split(':');
  if (parts.first != name) return false;
  final target = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
  final count = _hits[name] = (_hits[name] ?? 0) + 1;
  return count == target;
}

/// Para aqui: imprime o marcador e bloqueia o isolate sem ceder; o processo
/// só sai quando for morto.
Never crashpointNow(String name) {
  stdout.writeln('CRASHPOINT $name');
  while (true) {
    sleep(const Duration(hours: 1));
  }
}
