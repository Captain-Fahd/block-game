import 'package:block_puzzle/src/model/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('lineClearPoints', () {
    const table = {0: 0, 1: 10, 2: 30, 3: 60, 4: 100, 5: 150, 6: 200, 16: 700};
    table.forEach((lines, points) {
      test('$lines lines -> $points', () {
        expect(lineClearPoints(lines), points);
      });
    });
  });

  group('scorePlacement', () {
    // (description, cells, lines, boardEmpty, streakBefore, misses,
    //  expectedTotal, expectedStreakAfter, expectedMissesAfter)
    final cases = <(String, int, int, bool, int, int, int, int, int)>[
      ('plain placement scores 1 per cell', 4, 0, false, 0, 0, 4, 0, 1),
      ('first clear is x1', 3, 1, false, 0, 0, 3 + 10, 1, 0),
      ('second clear in a row is x2', 3, 1, false, 1, 0, 3 + 20, 2, 0),
      ('double clear on streak 2 is x3', 5, 2, false, 2, 0, 5 + 90, 3, 0),
      ('miss 1 keeps streak', 2, 0, false, 3, 0, 2, 3, 1),
      ('miss 2 keeps streak', 2, 0, false, 3, 1, 2, 3, 2),
      ('miss 3 resets streak', 2, 0, false, 3, 2, 2, 0, 0),
      (
        'clear after 2 misses keeps multiplier',
        1,
        1,
        false,
        3,
        2,
        1 + 40,
        4,
        0,
      ),
      ('board clear adds 300', 4, 2, true, 0, 0, 4 + 30 + 300, 1, 0),
      ('empty board without a clear gets no bonus', 1, 0, true, 0, 0, 1, 0, 1),
      ('5 lines', 9, 5, false, 0, 0, 9 + 150, 1, 0),
    ];

    for (final (name, cells, lines, empty, s, m, total, sAfter, mAfter)
        in cases) {
      test(name, () {
        final r = scorePlacement(
          cellsPlaced: cells,
          linesCleared: lines,
          boardEmptyAfter: empty,
          streak: (streak: s, missesSinceClear: m),
        );
        expect(r.total, total);
        expect(r.placementPoints + r.linePoints + r.boardClearBonus, r.total);
        expect(r.multiplier, 1 + s);
        expect(r.streakAfter, (streak: sAfter, missesSinceClear: mAfter));
      });
    }
  });
}
