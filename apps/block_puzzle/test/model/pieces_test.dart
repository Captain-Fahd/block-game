import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/model/piece.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // id -> (cells, width, height)
  const expected = <String, (int, int, int)>{
    'mono': (1, 1, 1),
    'domino_h': (2, 2, 1),
    'domino_v': (2, 1, 2),
    'I3_h': (3, 3, 1),
    'I3_v': (3, 1, 3),
    'I4_h': (4, 4, 1),
    'I4_v': (4, 1, 4),
    'I5_h': (5, 5, 1),
    'I5_v': (5, 1, 5),
    'L3_0': (3, 2, 2),
    'L3_90': (3, 2, 2),
    'L3_180': (3, 2, 2),
    'L3_270': (3, 2, 2),
    'L4_0': (4, 2, 3),
    'L4_90': (4, 3, 2),
    'L4_180': (4, 2, 3),
    'L4_270': (4, 3, 2),
    'J4_0': (4, 2, 3),
    'J4_90': (4, 3, 2),
    'J4_180': (4, 2, 3),
    'J4_270': (4, 3, 2),
    'T4_0': (4, 3, 2),
    'T4_90': (4, 2, 3),
    'T4_180': (4, 3, 2),
    'T4_270': (4, 2, 3),
    'S4_h': (4, 3, 2),
    'S4_v': (4, 2, 3),
    'Z4_h': (4, 3, 2),
    'Z4_v': (4, 2, 3),
    'O': (4, 2, 2),
    'SQ3': (9, 3, 3),
    'BL3_0': (5, 3, 3),
    'BL3_90': (5, 3, 3),
    'BL3_180': (5, 3, 3),
    'BL3_270': (5, 3, 3),
  };

  test('piece set matches the spec exactly', () {
    expect(kAllPieces.map((p) => p.id).toSet(), expected.keys.toSet());
    expect(kAllPieces.length, expected.length);
  });

  for (final entry in expected.entries) {
    test('${entry.key} has the right size and bounding box', () {
      final p = pieceById(entry.key);
      final (cells, w, h) = entry.value;
      expect(p.size, cells);
      expect(p.width, w);
      expect(p.height, h);
    });
  }

  test('orientations within a family are distinct shapes', () {
    final byFamily = <String, List<Piece>>{};
    for (final p in kAllPieces) {
      (byFamily[p.family] ??= []).add(p);
    }
    for (final pieces in byFamily.values) {
      final shapes = pieces.map((p) => p.cells.toSet().toString()).toSet();
      expect(shapes.length, pieces.length);
    }
  });

  test('every family has a weight in every band and a valid colour', () {
    final families = kAllPieces.map((p) => p.family).toSet();
    for (final band in kScoreBands) {
      expect(band.weights.keys.toSet(), families, reason: band.name);
    }
    for (final p in kAllPieces) {
      expect(p.colourIndex, inInclusiveRange(0, kColourCount - 1));
    }
  });

  test('pieceById rejects unknown ids', () {
    expect(() => pieceById('nope'), throwsArgumentError);
  });
}
