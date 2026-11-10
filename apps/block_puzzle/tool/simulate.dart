// Plays N games with a greedy bot and prints score, length and game-over
// cause statistics. Used to tune piece weights in lib/src/constants.dart.
//
//   dart run tool/simulate.dart [--games 500] [--seed 1] [--secs-per-move 3.5]
//                               [--casual]
//
// The bot looks one placement ahead, so it plays better than a casual human
// in some ways (never misplaces) and worse in others (no planning). Treat the
// numbers as relative: compare runs before and after a weight change.
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/piece.dart';
import 'package:block_puzzle/src/model/rng.dart';

typedef Move = (int slot, int row, int col);

/// Heuristic value of a board: penalise isolated holes, reward open space
/// in big rectangles via per-cell neighbour counts.
double evaluate(Board b) {
  var holes = 0;
  var roughness = 0;
  for (var r = 0; r < b.size; r++) {
    for (var c = 0; c < b.size; c++) {
      final filled = b.isFilled(r, c);
      var blockedNeighbours = 0;
      for (final (dr, dc) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
        final rr = r + dr, cc = c + dc;
        final edge = rr < 0 || cc < 0 || rr >= b.size || cc >= b.size;
        final nFilled = edge || b.isFilled(rr, cc);
        if (!filled && nFilled) blockedNeighbours++;
        if (!edge && filled != b.isFilled(rr, cc)) roughness++;
      }
      if (!filled && blockedNeighbours == 4) holes++;
    }
  }
  return -holes * 8.0 - roughness * 0.5 - b.filledCount * 0.3;
}

/// Best move by heuristic. With [casualRng], picks randomly among the top 3
/// moves instead, as a rough stand-in for a casual player.
Move? greedyMove(GameState s, {SeededRng? casualRng}) {
  final scored = <(double, Move)>[];
  for (var slot = 0; slot < s.tray.length; slot++) {
    final p = s.tray[slot];
    if (p == null) continue;
    for (final pos in s.board.validPositions(p)) {
      var b = s.board.place(p, pos.row, pos.col);
      final lines = b.findFullLines();
      final cleared = lines.rows.length + lines.cols.length;
      b = b.clearLines(lines);
      scored.add((cleared * 40.0 + evaluate(b), (slot, pos.row, pos.col)));
    }
  }
  if (scored.isEmpty) return null;
  scored.sort((a, b) => b.$1.compareTo(a.$1));
  if (casualRng == null) return scored.first.$2;
  final top = scored.length < 3 ? scored.length : 3;
  return scored[casualRng.nextInt(top)].$2;
}

double median(List<num> xs) {
  final s = [...xs]..sort();
  return s.isEmpty ? 0 : s[s.length ~/ 2].toDouble();
}

double percentile(List<num> xs, double p) {
  final s = [...xs]..sort();
  return s[((s.length - 1) * p).round()].toDouble();
}

void main(List<String> args) {
  int argInt(String name, int def) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? int.parse(args[i + 1]) : def;
  }

  double argDouble(String name, double def) {
    final i = args.indexOf('--$name');
    return i >= 0 && i + 1 < args.length ? double.parse(args[i + 1]) : def;
  }

  final games = argInt('games', 500);
  final seed0 = argInt('seed', 1);
  final secsPerMove = argDouble('secs-per-move', 3.5);
  final casual = args.contains('--casual');
  final botRng = SeededRng(seed0 * 7919);

  final scores = <int>[];
  final lengths = <int>[];
  final causes = <String, int>{};
  final sw = Stopwatch()..start();

  for (var g = 0; g < games; g++) {
    final game = GameController.newGame(
      mode: GameMode.classic,
      seed: seed0 + g,
    );
    while (!game.isOver) {
      final m = greedyMove(game.state, casualRng: casual ? botRng : null)!;
      game.place(m.$1, m.$2, m.$3);
    }
    scores.add(game.state.score);
    lengths.add(game.state.placements);
    final blocked = [...game.blockedPieces]
      ..sort((Piece a, Piece b) => b.size.compareTo(a.size));
    final cause = blocked.isEmpty ? 'none' : blocked.first.family;
    causes[cause] = (causes[cause] ?? 0) + 1;
  }

  final avgScore = scores.reduce((a, b) => a + b) / games;
  final avgLen = lengths.reduce((a, b) => a + b) / games;
  final medLen = median(lengths);
  print('Bot: ${casual ? 'casual (random of top 3)' : 'greedy'}');
  print(
    'Games: $games (seeds $seed0..${seed0 + games - 1}), '
    '${sw.elapsedMilliseconds} ms',
  );
  print(
    'Score     avg ${avgScore.toStringAsFixed(0)}  '
    'median ${median(scores).toStringAsFixed(0)}  '
    'p10 ${percentile(scores, .1).toStringAsFixed(0)}  '
    'p90 ${percentile(scores, .9).toStringAsFixed(0)}',
  );
  print(
    'Placements avg ${avgLen.toStringAsFixed(1)}  '
    'median ${medLen.toStringAsFixed(0)}  '
    'p10 ${percentile(lengths, .1).toStringAsFixed(0)}  '
    'p90 ${percentile(lengths, .9).toStringAsFixed(0)}',
  );
  print(
    'Est. median game length at ${secsPerMove}s/placement: '
    '${(medLen * secsPerMove / 60).toStringAsFixed(1)} min',
  );
  print('Game-over cause (largest blocked piece family):');
  final sorted = causes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in sorted) {
    print(
      '  ${e.key.padRight(7)} ${(e.value / games * 100).toStringAsFixed(1)}%',
    );
  }
  exitCode = 0;
}
