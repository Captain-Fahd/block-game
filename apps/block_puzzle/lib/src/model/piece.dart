import 'package:meta/meta.dart';

/// A cell offset (row, col) relative to a piece's top-left bounding box.
typedef CellOffset = ({int row, int col});

/// One orientation of a polyomino. Pieces are never rotated in play, so each
/// orientation is its own [Piece].
@immutable
class Piece {
  Piece({
    required this.id,
    required this.family,
    required this.colourIndex,
    required List<CellOffset> cells,
  }) : cells = List.unmodifiable(cells),
       width = cells.map((c) => c.col).reduce((a, b) => a > b ? a : b) + 1,
       height = cells.map((c) => c.row).reduce((a, b) => a > b ? a : b) + 1;

  /// Parses rows of `X` (filled) and `.` (empty), e.g. `['X.', 'XX']`.
  factory Piece.fromRows({
    required String id,
    required String family,
    required int colourIndex,
    required List<String> rows,
  }) {
    final cells = <CellOffset>[];
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (rows[r][c] == 'X') cells.add((row: r, col: c));
      }
    }
    return Piece(
      id: id,
      family: family,
      colourIndex: colourIndex,
      cells: cells,
    );
  }

  /// Stable id, used for serialisation (e.g. `L4_90`).
  final String id;

  /// Shape family shared by all orientations (e.g. `L4`); weights are per family.
  final String family;
  final int colourIndex;
  final List<CellOffset> cells;
  final int width;
  final int height;

  int get size => cells.length;

  @override
  String toString() => 'Piece($id)';
}
