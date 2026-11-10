import 'piece.dart';

Piece _p(String id, String family, int colour, List<String> rows) =>
    Piece.fromRows(id: id, family: family, colourIndex: colour, rows: rows);

/// The full piece set from the spec. Colours are per family, 0..7.
final List<Piece> kAllPieces = List.unmodifiable(<Piece>[
  _p('mono', 'mono', 0, ['X']),

  _p('domino_h', 'domino', 1, ['XX']),
  _p('domino_v', 'domino', 1, ['X', 'X']),

  _p('I3_h', 'I3', 2, ['XXX']),
  _p('I3_v', 'I3', 2, ['X', 'X', 'X']),

  _p('I4_h', 'I4', 3, ['XXXX']),
  _p('I4_v', 'I4', 3, ['X', 'X', 'X', 'X']),

  _p('I5_h', 'I5', 4, ['XXXXX']),
  _p('I5_v', 'I5', 4, ['X', 'X', 'X', 'X', 'X']),

  _p('L3_0', 'L3', 5, ['X.', 'XX']),
  _p('L3_90', 'L3', 5, ['XX', 'X.']),
  _p('L3_180', 'L3', 5, ['XX', '.X']),
  _p('L3_270', 'L3', 5, ['.X', 'XX']),

  _p('L4_0', 'L4', 6, ['X.', 'X.', 'XX']),
  _p('L4_90', 'L4', 6, ['XXX', 'X..']),
  _p('L4_180', 'L4', 6, ['XX', '.X', '.X']),
  _p('L4_270', 'L4', 6, ['..X', 'XXX']),

  _p('J4_0', 'J4', 7, ['.X', '.X', 'XX']),
  _p('J4_90', 'J4', 7, ['X..', 'XXX']),
  _p('J4_180', 'J4', 7, ['XX', 'X.', 'X.']),
  _p('J4_270', 'J4', 7, ['XXX', '..X']),

  _p('T4_0', 'T4', 0, ['XXX', '.X.']),
  _p('T4_90', 'T4', 0, ['.X', 'XX', '.X']),
  _p('T4_180', 'T4', 0, ['.X.', 'XXX']),
  _p('T4_270', 'T4', 0, ['X.', 'XX', 'X.']),

  _p('S4_h', 'S4', 1, ['.XX', 'XX.']),
  _p('S4_v', 'S4', 1, ['X.', 'XX', '.X']),

  _p('Z4_h', 'Z4', 2, ['XX.', '.XX']),
  _p('Z4_v', 'Z4', 2, ['.X', 'XX', 'X.']),

  _p('O', 'O', 3, ['XX', 'XX']),

  _p('SQ3', 'SQ3', 4, ['XXX', 'XXX', 'XXX']),

  _p('BL3_0', 'BL3', 5, ['X..', 'X..', 'XXX']),
  _p('BL3_90', 'BL3', 5, ['XXX', 'X..', 'X..']),
  _p('BL3_180', 'BL3', 5, ['XXX', '..X', '..X']),
  _p('BL3_270', 'BL3', 5, ['..X', '..X', 'XXX']),
]);

final Map<String, Piece> _byId = {for (final p in kAllPieces) p.id: p};

Piece pieceById(String id) {
  final p = _byId[id];
  if (p == null) throw ArgumentError.value(id, 'id', 'unknown piece');
  return p;
}
