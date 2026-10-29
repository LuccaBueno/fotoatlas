import 'dart:typed_data';

import 'package:fotoatlas_core/fotoatlas_core.dart';

import '../../l10n/format.dart';
import 'library_controller.dart';

/// Uma linha da galeria virtualizada: cabeçalho (ano/mês, dia, momento) ou
/// uma fileira de itens `[start, end)` do índice. Alturas fixas por tipo:
/// pular para um mês/dia/momento é só somar alturas.
sealed class LayoutRow {
  const LayoutRow();
  double get height;
}

enum HeaderKind { month, day, moment, noDate }

class HeaderRow extends LayoutRow {
  const HeaderRow(this.kind, this.key, {this.momentId, this.firstIndex = 0});
  final HeaderKind kind;

  /// AAAAMM (mês) ou AAAAMMDD (dia); 0 = sem data.
  final int key;
  final int? momentId;

  /// Primeiro item (no índice) sob este cabeçalho.
  final int firstIndex;

  @override
  double get height => switch (kind) {
    HeaderKind.month || HeaderKind.noDate => 52,
    HeaderKind.day => 44,
    HeaderKind.moment => 40,
  };
}

class ItemsRow extends LayoutRow {
  const ItemsRow(this.start, this.end, this.tileHeight);
  final int start;
  final int end;
  final double tileHeight;

  @override
  double get height => tileHeight + LibraryLayout.gap;
}

/// Fileiras + soma das alturas (para pular direto a um cabeçalho).
class LibraryLayout {
  LibraryLayout(this.rows) : offsets = Float64List(rows.length + 1) {
    for (var i = 0; i < rows.length; i++) {
      offsets[i + 1] = offsets[i] + rows[i].height;
    }
  }

  static const gap = 6.0;
  final List<LayoutRow> rows;
  final Float64List offsets;

  double offsetOfRow(int row) => offsets[row];

  /// Fileira do cabeçalho do mês/dia/momento [key] (mais perto), ou `null`.
  int? rowOf(HeaderKind kind, int key, {int? momentId}) {
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      if (r is HeaderRow && r.kind == kind && (momentId == null ? r.key == key : r.momentId == momentId)) return i;
    }
    return null;
  }

  /// Monta as fileiras: grade = cabeçalho por mês; linha do tempo = por dia e
  /// por momento (os momentos vêm do próprio índice, na ordem da tela).
  static LibraryLayout build(LibraryIndex index, LibraryView view, int columns, double tileHeight) {
    final rows = <LayoutRow>[];
    final n = index.length;
    var i = 0;
    while (i < n) {
      final day = index.day[i];
      final group = view == LibraryView.timeline ? day : day ~/ 100;
      // Grupo: mesmo dia (linha do tempo) ou mesmo mês (grade); sem data junto.
      var j = i + 1;
      while (j < n && (view == LibraryView.timeline ? index.day[j] : index.day[j] ~/ 100) == group) {
        j++;
      }
      if (day == 0) {
        rows.add(HeaderRow(HeaderKind.noDate, 0, firstIndex: i));
        _items(rows, i, j, columns, tileHeight);
      } else if (view == LibraryView.timeline) {
        // Cabeçalho de mês quando o mês muda (navegação), depois o dia.
        final prevMonth = i == 0 ? -1 : index.day[i - 1] ~/ 100;
        if (prevMonth != day ~/ 100) rows.add(HeaderRow(HeaderKind.month, day ~/ 100, firstIndex: i));
        rows.add(HeaderRow(HeaderKind.day, day, firstIndex: i));
        var k = i;
        while (k < j) {
          final m = index.moment[k];
          var e = k + 1;
          while (e < j && index.moment[e] == m) {
            e++;
          }
          if (m != 0) rows.add(HeaderRow(HeaderKind.moment, day, momentId: m, firstIndex: k));
          _items(rows, k, e, columns, tileHeight);
          k = e;
        }
      } else {
        rows.add(HeaderRow(HeaderKind.month, group, firstIndex: i));
        _items(rows, i, j, columns, tileHeight);
      }
      i = j;
    }
    return LibraryLayout(rows);
  }

  static void _items(List<LayoutRow> rows, int start, int end, int columns, double tileHeight) {
    for (var s = start; s < end; s += columns) {
      rows.add(ItemsRow(s, s + columns < end ? s + columns : end, tileHeight));
    }
  }
}

/// "Maio de 2024" a partir de AAAAMM.
String monthLabel(int yyyymm) => yyyymm == 0 ? 'Sem data' : formatMonthYear(yyyymm ~/ 100, yyyymm % 100);

/// "Quarta-feira, 1 de maio de 2024" a partir de AAAAMMDD.
String dayLabel(int yyyymmdd) => yyyymmdd == 0
    ? 'Sem data'
    : formatLongDay(DateTime.utc(yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100));
