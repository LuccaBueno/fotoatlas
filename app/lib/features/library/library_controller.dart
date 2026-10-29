import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../app/library_backend.dart';
import '../../app/providers.dart';

enum LibraryView { timeline, grid, list }

class LibraryState {
  LibraryState({
    this.filter = LibraryFilter.empty,
    this.view = LibraryView.timeline,
    this.ascending = false,
    LibraryIndex? index,
    this.loading = true,
    this.error,
    this.selection = const {},
    this.anchor,
    this.focused,
  }) : index = index ?? LibraryIndex.empty;

  final LibraryFilter filter;
  final LibraryView view;

  /// `false` = mais novas primeiro.
  final bool ascending;
  final LibraryIndex index;
  final bool loading;
  final String? error;

  /// Itens marcados (IDs de conteúdo); pode ter itens fora do filtro atual.
  final Set<int> selection;

  /// Ponto de partida do Shift+clique.
  final int? anchor;

  /// Item cujo painel de detalhes está aberto.
  final int? focused;

  LibraryState copyWith({
    LibraryFilter? filter,
    LibraryView? view,
    bool? ascending,
    LibraryIndex? index,
    bool? loading,
    String? error,
    bool clearError = false,
    Set<int>? selection,
    int? anchor,
    int? focused,
    bool clearFocus = false,
  }) => LibraryState(
    filter: filter ?? this.filter,
    view: view ?? this.view,
    ascending: ascending ?? this.ascending,
    index: index ?? this.index,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    selection: selection ?? this.selection,
    anchor: anchor ?? this.anchor,
    focused: clearFocus ? null : (focused ?? this.focused),
  );
}

final libraryControllerProvider = NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

/// Consulta, ordem, visão e seleção da Biblioteca.
class LibraryController extends Notifier<LibraryState> {
  int _generation = 0;

  LibraryBackend get _backend => ref.read(libraryBackendProvider);

  @override
  LibraryState build() {
    ref.listen(libraryChangesProvider, (_, _) => reload(), fireImmediately: false);
    Future.microtask(reload);
    return LibraryState();
  }

  Future<void> reload() async {
    final gen = ++_generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final index = await _backend.index(state.filter, ascending: state.ascending);
      if (gen != _generation) return;
      ref.read(libraryItemCacheProvider).clear();
      state = state.copyWith(index: index, loading: false);
    } on Object catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(loading: false, error: 'Não foi possível carregar a Biblioteca: $e');
    }
  }

  void setFilter(LibraryFilter filter) {
    state = state.copyWith(filter: filter);
    reload();
  }

  void setCondition(FilterCondition? c, FilterKind kind) =>
      setFilter(c == null ? state.filter.without(kind) : state.filter.withCondition(c));

  void setView(LibraryView view) => state = state.copyWith(view: view);

  void setAscending(bool value) {
    state = state.copyWith(ascending: value);
    reload();
  }

  /// Clique (só este), Ctrl+clique (alterna) e Shift+clique (intervalo).
  void tap(int id, {bool ctrl = false, bool shift = false}) {
    final ids = state.index.ids;
    if (shift && state.anchor != null) {
      final a = ids.indexOf(state.anchor!);
      final b = ids.indexOf(id);
      if (a >= 0 && b >= 0) {
        final range = {for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) ids[i]};
        state = state.copyWith(selection: ctrl ? {...state.selection, ...range} : range, focused: id);
        return;
      }
    }
    if (ctrl) {
      final sel = {...state.selection};
      if (!sel.remove(id)) sel.add(id);
      state = state.copyWith(selection: sel, anchor: id, focused: id);
      return;
    }
    state = state.copyWith(selection: {id}, anchor: id, focused: id);
  }

  void toggle(int id) {
    final sel = {...state.selection};
    if (!sel.remove(id)) sel.add(id);
    state = state.copyWith(selection: sel, anchor: id);
  }

  /// Todos os resultados do filtro (não só os visíveis).
  void selectAll() => state = state.copyWith(selection: {...state.selection, ...state.index.ids});

  /// Inverte dentro dos resultados do filtro.
  void invert() {
    final inResults = state.index.ids.toSet();
    state = state.copyWith(
      selection: {
        ...state.selection.where((id) => !inResults.contains(id)),
        ...inResults.where((id) => !state.selection.contains(id)),
      },
    );
  }

  void clearSelection() => state = state.copyWith(selection: const {});

  void selectIds(Iterable<int> ids) => state = state.copyWith(selection: ids.toSet());

  /// Tira da seleção os itens que atendem a [criterion].
  Future<int> removeFromSelection(LibraryFilter criterion) async {
    final matching = (await _backend.index(criterion)).ids.toSet();
    final before = state.selection.length;
    state = state.copyWith(selection: state.selection.where((id) => !matching.contains(id)).toSet());
    return before - state.selection.length;
  }

  void focus(int? id) => state = id == null ? state.copyWith(clearFocus: true) : state.copyWith(focused: id);
}

/// Itens carregados por página, pedidos em lote (vários quadrinhos pedem no
/// mesmo quadro → uma consulta).
class LibraryItemCache {
  LibraryItemCache(this._backend);
  final LibraryBackend _backend;
  final Map<int, LibraryItem> _items = {};
  final Map<int, Completer<LibraryItem?>> _waiting = {};
  bool _scheduled = false;

  LibraryItem? peek(int id) => _items[id];

  Future<LibraryItem?> get(int id) {
    final hit = _items[id];
    if (hit != null) return Future.value(hit);
    final c = _waiting[id] ??= Completer<LibraryItem?>();
    if (!_scheduled) {
      _scheduled = true;
      Timer.run(_flush);
    }
    return c.future;
  }

  Future<void> _flush() async {
    _scheduled = false;
    final batch = Map.of(_waiting);
    _waiting.clear();
    if (batch.isEmpty) return;
    try {
      final items = await _backend.items(batch.keys.toList());
      for (final i in items) {
        _items[i.contentId] = i;
      }
      if (_items.length > 5000) _items.clear();
      for (final e in batch.entries) {
        e.value.complete(_items[e.key]);
      }
    } on Object {
      for (final c in batch.values) {
        if (!c.isCompleted) c.complete(null);
      }
    }
  }

  void clear() => _items.clear();
}

final libraryItemCacheProvider = Provider<LibraryItemCache>(
  (ref) => LibraryItemCache(ref.watch(libraryBackendProvider)),
);

/// Miniaturas pedidas (um pedido por item; o core gera no máximo 3 por vez).
class ThumbnailCache {
  ThumbnailCache(this._backend);
  final LibraryBackend _backend;
  final Map<int, Future<String?>> _requests = {};

  Future<String?> get(int contentId) {
    if (_requests.length > 4000) _requests.clear();
    return _requests[contentId] ??= _backend.thumbnail(contentId);
  }
}

final thumbnailCacheProvider = Provider<ThumbnailCache>((ref) => ThumbnailCache(ref.watch(libraryBackendProvider)));
