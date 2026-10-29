import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/providers.dart';

enum CompareSide { a, b }

/// Um lado da comparação sendo montado na tela.
class ScopeDraft {
  const ScopeDraft({
    this.entries = const [],
    this.types = const {},
    this.savedName,
    this.moments = const [],
    this.filter,
  });

  final List<ScopeEntry> entries;

  /// Momentos (em todos os dispositivos ou só numa fonte).
  final List<MomentScopeEntry> moments;

  /// Filtro por data/câmera (`null` = nenhum).
  final LibraryFilter? filter;

  /// Vazio = todos os tipos.
  final Set<ScopeFileType> types;

  /// Nome do escopo salvo de onde veio (some se o usuário mexer).
  final String? savedName;

  Scope toScope() => Scope(entries, types: types, moments: moments, filter: filter);
  bool get isEmpty => entries.isEmpty && moments.isEmpty;

  ScopeDraft copyWith({
    List<ScopeEntry>? entries,
    Set<ScopeFileType>? types,
    String? savedName,
    bool keepName = false,
    List<MomentScopeEntry>? moments,
    LibraryFilter? filter,
    bool clearFilter = false,
  }) => ScopeDraft(
    entries: entries ?? this.entries,
    types: types ?? this.types,
    savedName: savedName ?? (keepName ? this.savedName : null),
    moments: moments ?? this.moments,
    filter: clearFilter ? null : (filter ?? this.filter),
  );
}

class CompareState {
  const CompareState({
    this.a = const ScopeDraft(),
    this.b = const ScopeDraft(),
    this.result,
    this.resultA,
    this.resultB,
    this.running = false,
    this.error,
  });

  final ScopeDraft a;
  final ScopeDraft b;
  final CompareSummary? result;

  /// Escopos que produziram [result] (as listas usam estes).
  final Scope? resultA;
  final Scope? resultB;
  final bool running;
  final String? error;

  ScopeDraft side(CompareSide s) => s == CompareSide.a ? a : b;
  bool get canCompare => !a.isEmpty && !b.isEmpty && !running;

  CompareState copyWith({
    ScopeDraft? a,
    ScopeDraft? b,
    CompareSummary? result,
    Scope? resultA,
    Scope? resultB,
    bool? running,
    String? error,
    bool clearError = false,
  }) => CompareState(
    a: a ?? this.a,
    b: b ?? this.b,
    result: result ?? this.result,
    resultA: resultA ?? this.resultA,
    resultB: resultB ?? this.resultB,
    running: running ?? this.running,
    error: clearError ? null : (error ?? this.error),
  );
}

final compareControllerProvider = NotifierProvider<CompareController, CompareState>(CompareController.new);

/// Monta os escopos A e B, compara e refaz a comparação quando a conferência
/// de conteúdo termina (o resultado "incompleto" vai se resolvendo sozinho).
class CompareController extends Notifier<CompareState> {
  bool _wasHashing = false;

  @override
  CompareState build() {
    ref.listen(hashStatusProvider, (_, next) {
      final running = next.value?.running ?? false;
      if (_wasHashing && !running && state.result != null) rerun();
      _wasHashing = running;
    });
    return const CompareState();
  }

  void _setSide(CompareSide s, ScopeDraft d) =>
      state = s == CompareSide.a ? state.copyWith(a: d) : state.copyWith(b: d);

  void addEntry(CompareSide s, ScopeEntry entry) {
    final d = state.side(s);
    // A simplificação (pasta dentro de outra entrada) fica com o core.
    _setSide(s, d.copyWith(entries: Scope([...d.entries, entry]).entries));
  }

  void removeEntry(CompareSide s, ScopeEntry entry) {
    final d = state.side(s);
    _setSide(s, d.copyWith(entries: [...d.entries]..remove(entry)));
  }

  void toggleType(CompareSide s, ScopeFileType type) {
    final d = state.side(s);
    final types = {...d.types};
    if (!types.remove(type)) types.add(type);
    _setSide(s, d.copyWith(types: types));
  }

  void loadSaved(CompareSide s, SavedScope saved) => _setSide(
    s,
    ScopeDraft(
      entries: saved.scope.entries,
      types: saved.scope.types ?? const {},
      savedName: saved.name,
      moments: saved.scope.moments,
      filter: saved.scope.filter,
    ),
  );

  void addMoment(CompareSide s, MomentScopeEntry m) {
    final d = state.side(s);
    if (d.moments.contains(m)) return;
    _setSide(s, d.copyWith(moments: [...d.moments, m]));
  }

  void removeMoment(CompareSide s, MomentScopeEntry m) {
    final d = state.side(s);
    _setSide(s, d.copyWith(moments: [...d.moments]..remove(m)));
  }

  void setFilter(CompareSide s, LibraryFilter? f) {
    final d = state.side(s);
    _setSide(s, f == null || f.isEmpty ? d.copyWith(clearFilter: true) : d.copyWith(filter: f));
  }

  void markSaved(CompareSide s, String name) => _setSide(s, state.side(s).copyWith(savedName: name));

  void clearSide(CompareSide s) => _setSide(s, const ScopeDraft());

  void swap() => state = CompareState(a: state.b, b: state.a);

  Future<void> run() async {
    if (state.a.isEmpty || state.b.isEmpty) return;
    final a = state.a.toScope(), b = state.b.toScope();
    state = state.copyWith(running: true, clearError: true);
    try {
      final result = await ref.read(backendProvider).compare(a, b);
      state = state.copyWith(result: result, resultA: a, resultB: b, running: false);
    } on Object catch (e) {
      state = state.copyWith(running: false, error: 'Não foi possível comparar: $e');
    }
  }

  /// Refaz com os mesmos escopos do último resultado.
  Future<void> rerun() async {
    final a = state.resultA, b = state.resultB;
    if (a == null || b == null || state.running) return;
    try {
      final result = await ref.read(backendProvider).compare(a, b);
      state = state.copyWith(result: result);
    } on Object {
      // Mantém o resultado anterior; o usuário pode comparar de novo.
    }
  }

  /// "Conferir agora": põe os arquivos dos dois escopos na frente da fila.
  Future<void> verifyNow() async {
    final a = state.resultA, b = state.resultB;
    if (a == null || b == null) return;
    _wasHashing = true;
    await ref.read(backendProvider).startHash(priority: CompareService.priorityFor([a, b]));
  }
}
