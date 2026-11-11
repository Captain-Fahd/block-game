import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/snap.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  bool all(int r, int c) => true;

  group('findSnap', () {
    test('picks the nearest cell when it fits', () {
      expect(findSnap(row: 2.3, col: 4.6, fits: all), (row: 2, col: 5));
    });

    test('falls back to the closest fitting neighbour', () {
      bool notNearest(int r, int c) => !(r == 2 && c == 5);
      expect(findSnap(row: 2.3, col: 4.6, fits: notNearest), (row: 2, col: 4));
    });

    test('nothing within tolerance -> null', () {
      bool only(int r, int c) => r == 5 && c == 5;
      expect(findSnap(row: 2, col: 2, fits: only), isNull);
    });

    test('a spot exactly one cell away is beyond the default tolerance', () {
      expect(kSnapToleranceCells, lessThan(1));
      bool right(int r, int c) => r == 3 && c == 4;
      expect(findSnap(row: 3, col: 3, fits: right), isNull);
      expect(findSnap(row: 3, col: 3.2, fits: right), (row: 3, col: 4));
    });

    test('works past the board edge (negative positions)', () {
      bool onBoard(int r, int c) => r >= 0 && c >= 0 && r <= 7 && c <= 7;
      expect(findSnap(row: 0.2, col: -0.6, fits: onBoard), (row: 0, col: 0));
    });
  });
}
