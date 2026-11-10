import 'package:meta/meta.dart';

import '../constants.dart';
import 'piece.dart';

/// Rows and columns that are full after a placement.
typedef FullLines = ({List<int> rows, List<int> cols});

/// Immutable square board. Each cell is `-1` (empty) or a colour index.
@immutable
class Board {
  Board.empty([this.size = kBoardSize])
    : _cells = List<int>.filled(size * size, emptyCell, growable: false);

  Board._(this.size, List<int> cells) : _cells = List.unmodifiable(cells);

  /// Builds a board from rows of `.` (empty) and digits (colour index).
  factory Board.fromRows(List<String> rows) {
    final size = rows.length;
    final cells = <int>[];
    for (final row in rows) {
      if (row.length != size) throw ArgumentError('board must be square');
      for (final ch in row.split('')) {
        cells.add(ch == '.' ? emptyCell : int.parse(ch));
      }
    }
    return Board._(size, cells);
  }

  factory Board.fromJson(Map<String, dynamic> json) =>
      Board._(json['size'] as int, (json['cells'] as List).cast<int>());

  static const int emptyCell = -1;

  final int size;
  final List<int> _cells;

  int at(int row, int col) => _cells[row * size + col];
  bool isFilled(int row, int col) => at(row, col) != emptyCell;

  bool get isEmpty => _cells.every((c) => c == emptyCell);
  int get filledCount => _cells.where((c) => c != emptyCell).length;

  bool canPlace(Piece piece, int row, int col) {
    if (row < 0 || col < 0) return false;
    if (row + piece.height > size || col + piece.width > size) return false;
    for (final c in piece.cells) {
      if (isFilled(row + c.row, col + c.col)) return false;
    }
    return true;
  }

  /// Returns a new board with [piece] placed. Throws if it doesn't fit.
  Board place(Piece piece, int row, int col) {
    if (!canPlace(piece, row, col)) {
      throw StateError('$piece does not fit at ($row, $col)');
    }
    final next = List<int>.of(_cells);
    for (final c in piece.cells) {
      next[(row + c.row) * size + (col + c.col)] = piece.colourIndex;
    }
    return Board._(size, next);
  }

  FullLines findFullLines() {
    final rows = <int>[];
    final cols = <int>[];
    for (var i = 0; i < size; i++) {
      var rowFull = true;
      var colFull = true;
      for (var j = 0; j < size; j++) {
        if (!isFilled(i, j)) rowFull = false;
        if (!isFilled(j, i)) colFull = false;
      }
      if (rowFull) rows.add(i);
      if (colFull) cols.add(i);
    }
    return (rows: rows, cols: cols);
  }

  /// Clears the given lines at once. A cell in both a cleared row and a
  /// cleared column is cleared once.
  Board clearLines(FullLines lines) {
    if (lines.rows.isEmpty && lines.cols.isEmpty) return this;
    final next = List<int>.of(_cells);
    for (final r in lines.rows) {
      for (var c = 0; c < size; c++) {
        next[r * size + c] = emptyCell;
      }
    }
    for (final c in lines.cols) {
      for (var r = 0; r < size; r++) {
        next[r * size + c] = emptyCell;
      }
    }
    return Board._(size, next);
  }

  /// All cells that [lines] would clear, deduplicated.
  Set<CellOffset> cellsIn(FullLines lines) => {
    for (final r in lines.rows)
      for (var c = 0; c < size; c++) (row: r, col: c),
    for (final c in lines.cols)
      for (var r = 0; r < size; r++) (row: r, col: c),
  };

  bool anyFit(Piece piece) {
    for (var r = 0; r <= size - piece.height; r++) {
      for (var c = 0; c <= size - piece.width; c++) {
        if (canPlace(piece, r, c)) return true;
      }
    }
    return false;
  }

  Iterable<CellOffset> validPositions(Piece piece) sync* {
    for (var r = 0; r <= size - piece.height; r++) {
      for (var c = 0; c <= size - piece.width; c++) {
        if (canPlace(piece, r, c)) yield (row: r, col: c);
      }
    }
  }

  Map<String, dynamic> toJson() => {'size': size, 'cells': _cells};

  @override
  bool operator ==(Object other) {
    if (other is! Board || other.size != size) return false;
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] != other._cells[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(size, Object.hashAll(_cells));

  @override
  String toString() {
    final b = StringBuffer();
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final v = at(r, c);
        b.write(v == emptyCell ? '.' : '$v');
      }
      if (r < size - 1) b.writeln();
    }
    return b.toString();
  }
}
