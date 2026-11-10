import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mono = pieceById('mono');
  final i5h = pieceById('I5_h');
  final sq3 = pieceById('SQ3');

  test('empty board', () {
    final b = Board.empty();
    expect(b.size, 8);
    expect(b.isEmpty, isTrue);
    expect(b.filledCount, 0);
    expect(b.findFullLines().rows, isEmpty);
  });

  group('canPlace', () {
    final b = Board.empty();
    test('fits at all four corners', () {
      expect(b.canPlace(sq3, 0, 0), isTrue);
      expect(b.canPlace(sq3, 0, 5), isTrue);
      expect(b.canPlace(sq3, 5, 0), isTrue);
      expect(b.canPlace(sq3, 5, 5), isTrue);
    });
    test('rejects off-board positions', () {
      expect(b.canPlace(sq3, 6, 0), isFalse);
      expect(b.canPlace(sq3, 0, 6), isFalse);
      expect(b.canPlace(mono, -1, 0), isFalse);
      expect(b.canPlace(mono, 0, -1), isFalse);
      expect(b.canPlace(i5h, 0, 4), isFalse);
    });
    test('rejects overlap', () {
      final placed = b.place(mono, 1, 1);
      expect(placed.canPlace(sq3, 0, 0), isFalse);
      expect(placed.canPlace(sq3, 2, 2), isTrue);
    });
    test('L shapes only need their own cells empty', () {
      final board = Board.fromRows([
        '.1......',
        '.1......',
        '........',
        '........',
        '........',
        '........',
        '........',
        '........',
      ]);
      // BL3_0: X.. / X.. / XXX — the gap at (0,1) and (1,1) is unused.
      expect(board.canPlace(pieceById('BL3_0'), 0, 0), isTrue);
      expect(board.canPlace(pieceById('SQ3'), 0, 0), isFalse);
    });
  });

  test('place is immutable and throws when it does not fit', () {
    final b = Board.empty();
    final b2 = b.place(sq3, 0, 0);
    expect(b.isEmpty, isTrue);
    expect(b2.filledCount, 9);
    expect(b2.at(2, 2), sq3.colourIndex);
    expect(() => b2.place(mono, 1, 1), throwsStateError);
  });

  test('finds and clears a full row', () {
    final b = Board.fromRows([
      '11111111',
      '1.......',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final lines = b.findFullLines();
    expect(lines.rows, [0]);
    expect(lines.cols, isEmpty);
    final cleared = b.clearLines(lines);
    expect(cleared.filledCount, 1);
    expect(cleared.isFilled(1, 0), isTrue);
  });

  test('row and column overlap clears the shared cell once', () {
    final b = Board.fromRows([
      '22222222',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2.......',
      '2......3',
    ]);
    final lines = b.findFullLines();
    expect(lines.rows, [0]);
    expect(lines.cols, [0]);
    expect(b.cellsIn(lines).length, 15);
    final cleared = b.clearLines(lines);
    expect(cleared.filledCount, 1);
    expect(cleared.at(7, 7), 3);
  });

  test('clearing nothing returns the same board', () {
    final b = Board.empty().place(mono, 3, 3);
    expect(identical(b.clearLines((rows: [], cols: [])), b), isTrue);
  });

  test('full board: every line full, nothing fits, clears to empty', () {
    final b = Board.fromRows(List.filled(8, '44444444'));
    final lines = b.findFullLines();
    expect(lines.rows.length, 8);
    expect(lines.cols.length, 8);
    expect(b.anyFit(mono), isFalse);
    expect(b.clearLines(lines).isEmpty, isTrue);
  });

  test('anyFit and validPositions', () {
    final b = Board.fromRows([
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '11111111',
      '111.....',
      '11111111',
      '11111111',
    ]);
    expect(b.anyFit(i5h), isTrue);
    expect(b.validPositions(i5h).toList(), [(row: 5, col: 3)]);
    expect(b.anyFit(pieceById('I5_v')), isFalse);
    expect(b.anyFit(sq3), isFalse);
    expect(b.validPositions(mono).length, 5);
  });

  test('JSON round trip and equality', () {
    final b = Board.empty().place(sq3, 2, 3).place(mono, 7, 7);
    final restored = Board.fromJson(b.toJson());
    expect(restored, b);
    expect(restored.hashCode, b.hashCode);
    expect(restored.toString(), b.toString());
    expect(restored == Board.empty(), isFalse);
  });

  test('fromRows rejects non-square input', () {
    expect(() => Board.fromRows(['..', '...']), throwsArgumentError);
  });
}
