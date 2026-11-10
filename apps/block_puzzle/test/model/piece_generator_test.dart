import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/daily_seed.dart';
import 'package:block_puzzle/src/model/piece_generator.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:block_puzzle/src/model/rng.dart';
import 'package:flutter_test/flutter_test.dart';

/// A random board with roughly [fill] of cells filled and no full lines.
Board randomBoard(SeededRng rng, double fill) {
  final rows = <String>[];
  for (var r = 0; r < kBoardSize; r++) {
    final b = StringBuffer();
    for (var c = 0; c < kBoardSize; c++) {
      b.write(rng.nextDouble() < fill ? '1' : '.');
    }
    rows.add(b.toString());
  }
  final board = Board.fromRows(rows);
  return board.clearLines(board.findFullLines());
}

void main() {
  group('SeededRng', () {
    test('same seed gives the same sequence; state resumes exactly', () {
      final a = SeededRng(42);
      final b = SeededRng(42);
      final seqA = [for (var i = 0; i < 100; i++) a.nextUint32()];
      expect([for (var i = 0; i < 100; i++) b.nextUint32()], seqA);

      final c = SeededRng.fromState(a.state);
      expect(c.nextUint32(), a.nextUint32());
    });

    test('values stay in range', () {
      final r = SeededRng(7);
      for (var i = 0; i < 10000; i++) {
        final d = r.nextDouble();
        expect(d >= 0 && d < 1, isTrue);
        expect(r.nextInt(5), inInclusiveRange(0, 4));
      }
      expect(() => r.nextInt(0), throwsArgumentError);
    });

    test('seed 0 and the scramble fixed point still work', () {
      expect(SeededRng(0).nextUint32(), isNot(0));
    });
  });

  group('dailySeed', () {
    test('same date gives the same seed, time of day ignored', () {
      expect(
        dailySeed(DateTime(2027, 1, 15, 3)),
        dailySeed(DateTime(2027, 1, 15, 23, 59)),
      );
      expect(dailyKey(DateTime(2027, 1, 5)), '20270105');
    });
    test('adjacent dates differ and give different first trays', () {
      final a = dailySeed(DateTime(2027, 1, 15));
      final b = dailySeed(DateTime(2027, 1, 16));
      final c = dailySeed(DateTime(2027, 2, 1));
      expect({a, b, c}.length, 3);
      expect(SeededRng(a).nextUint32(), isNot(SeededRng(b).nextUint32()));
    });
  });

  group('PieceGenerator', () {
    test('same seed gives the same trays', () {
      List<String> run(int seed) {
        final g = PieceGenerator(SeededRng(seed));
        return [
          for (var i = 0; i < 50; i++)
            ...g.nextTray(Board.empty(), score: i * 200)!.map((p) => p.id),
        ];
      }

      expect(run(123), run(123));
      expect(run(123), isNot(run(124)));
    });

    test('first tray only has pieces of size <= 3', () {
      for (var seed = 0; seed < 500; seed++) {
        final tray = PieceGenerator(SeededRng(seed))
            .nextTray(Board.empty(), score: 0, firstTray: true)!;
        expect(tray.length, kTraySize);
        expect(tray.every((p) => p.size <= kFirstTrayMaxPieceSize), isTrue);
      }
    });

    test('bands pick by score', () {
      final g = PieceGenerator(SeededRng(1));
      expect(g.bandFor(0).name, 'easy');
      expect(g.bandFor(1499).name, 'easy');
      expect(g.bandFor(1500).name, 'normal');
      expect(g.bandFor(1000000).name, 'hard');
    });

    test('weights shift: fewer monos and more SQ3 at high scores', () {
      int count(int score, String family) {
        final g = PieceGenerator(SeededRng(99));
        final band = g.bandFor(score);
        var n = 0;
        for (var i = 0; i < 20000; i++) {
          if (g.pick(kAllPieces, band).family == family) n++;
        }
        return n;
      }

      expect(count(0, 'mono'), greaterThan(count(10000, 'mono')));
      expect(count(0, 'SQ3'), lessThan(count(10000, 'SQ3')));
    });

    test('zero weights fall back to a uniform pick', () {
      final g = PieceGenerator(SeededRng(5));
      const band = ScoreBand('zero', 0, {});
      expect(kAllPieces, contains(g.pick(kAllPieces, band)));
    });

    test('fairness holds over 10,000 random boards', () {
      final boardRng = SeededRng(2024);
      final g = PieceGenerator(SeededRng(77));
      for (var i = 0; i < 10000; i++) {
        final board = randomBoard(boardRng, 0.3 + 0.5 * boardRng.nextDouble());
        final tray = g.nextTray(board, score: boardRng.nextInt(8000));
        if (kAllPieces.any(board.anyFit)) {
          expect(tray, isNotNull);
          expect(tray!.length, kTraySize);
          expect(tray.any(board.anyFit), isTrue, reason: '$board');
        } else {
          expect(tray, isNull);
        }
      }
    });

    test('fallback path: replaces a piece with the largest one that fits', () {
      // Only weight SQ3, which never fits; the only gap is a 1x2 hole.
      const band = ScoreBand('sq', 0, {'SQ3': 1});
      final g = PieceGenerator(SeededRng(3), bands: const [band]);
      final board = Board.fromRows([
        '11111111',
        '1111111.',
        '1111111.',
        '11111111',
        '1.111111',
        '11111111',
        '11111111',
        '11111111',
      ]);
      final tray = g.nextTray(board, score: 0)!;
      expect(tray.where((p) => p.id == 'SQ3').length, kTraySize - 1);
      expect(tray.where((p) => p.id == 'domino_v').length, 1);
    });

    test('returns null when nothing fits', () {
      final g = PieceGenerator(SeededRng(3));
      final full = Board.fromRows(List.filled(8, '11111111'));
      expect(g.nextTray(full, score: 0), isNull);
      expect(g.secondChanceTray(full, score: 0), isNull);
    });

    test('second-chance trays: every piece fits on its own', () {
      final boardRng = SeededRng(11);
      final g = PieceGenerator(SeededRng(12));
      for (var i = 0; i < 2000; i++) {
        final board = randomBoard(boardRng, 0.75);
        final tray = g.secondChanceTray(board, score: 3000);
        if (tray == null) continue;
        expect(tray.length, kTraySize);
        expect(tray.every(board.anyFit), isTrue);
      }
    });
  });
}
