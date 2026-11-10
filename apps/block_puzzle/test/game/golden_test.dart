import 'package:block_puzzle/src/game/block_game.dart';
import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:block_puzzle/src/model/rng.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';

// Golden images of the board in fixed states, at a 360x640 small-phone size.
// Regenerate after an intentional visual change with:
//   flutter test --update-goldens test/game/golden_test.dart

const _midGame = [
  '........',
  '..55....',
  '..5.....',
  '0000.11.',
  '...2.11.',
  '...2....',
  '6..2..77',
  '66.3333.',
];

BlockGame _game(
  List<String> rows, {
  List<String?> tray = const ['L4_0', 'O', 'I3_v'],
  int score = 0,
  bool colourBlind = false,
}) => BlockGame(
  pixelRatio: 1,
  best: 1200,
  colourBlind: ValueNotifier(colourBlind),
  controller: GameController.fromState(
    GameState(
      mode: GameMode.classic,
      seed: 1,
      board: Board.fromRows(rows),
      tray: [for (final id in tray) id == null ? null : pieceById(id)],
      score: score,
      streak: (streak: 2, missesSinceClear: 0),
      rngState: SeededRng(1).state,
    ),
  ),
);

final _size = Vector2(360, 640);

Future<void> _settle(BlockGame game) async {
  await game.ready();
  game.update(1); // finish deal-in animations
  await game.ready();
}

void main() {
  testGolden(
    'empty board',
    (game, tester) async => _settle(game as BlockGame),
    game: _game(
      List.filled(8, '........'),
      tray: const ['mono', 'L3_0', 'I3_h'],
    )..best = 0,
    size: _size,
    goldenFile: 'goldens/empty.png',
  );

  testGolden(
    'mid-game',
    (game, tester) async => _settle(game as BlockGame),
    game: _game(_midGame, score: 840),
    size: _size,
    goldenFile: 'goldens/mid_game.png',
  );

  testGolden(
    'ghost valid',
    (game, tester) async {
      final g = game as BlockGame;
      await _settle(g);
      g.ghost = (piece: pieceById('O'), row: 0, col: 5, valid: true);
    },
    game: _game(_midGame, score: 840),
    size: _size,
    goldenFile: 'goldens/ghost_valid.png',
  );

  testGolden(
    'ghost invalid',
    (game, tester) async {
      final g = game as BlockGame;
      await _settle(g);
      g.ghost = (piece: pieceById('L4_0'), row: 3, col: 3, valid: false);
    },
    game: _game(_midGame, score: 840),
    size: _size,
    goldenFile: 'goldens/ghost_invalid.png',
  );

  testGolden(
    'colour-blind patterns',
    (game, tester) async => _settle(game as BlockGame),
    game: _game(
      _midGame,
      score: 840,
      colourBlind: true,
      tray: const ['T4_0', 'S4_h', 'mono'],
    ),
    size: _size,
    goldenFile: 'goldens/colour_blind.png',
  );
}
