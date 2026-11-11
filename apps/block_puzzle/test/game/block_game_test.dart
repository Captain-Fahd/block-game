import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/block_game.dart';
import 'package:block_puzzle/src/game/components/effects.dart';
import 'package:block_puzzle/src/game/sfx.dart';
import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/piece.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:block_puzzle/src/model/rng.dart';
import 'package:block_puzzle/src/model/scoring.dart';
import 'package:flame/components.dart';
import 'package:flame_test/flame_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

const _empty = [
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
  '........',
];

GameController controllerWith({
  List<String> board = _empty,
  List<String?> tray = const ['I3_h', 'mono', 'O'],
  int score = 0,
}) => GameController.fromState(
  GameState(
    mode: GameMode.classic,
    seed: 1,
    board: Board.fromRows(board),
    tray: [for (final id in tray) id == null ? null : pieceById(id)],
    score: score,
    streak: kInitialStreak,
    rngState: SeededRng(1).state,
  ),
);

class _Harness {
  _Harness({
    GameController? controller,
    int best = 0,
    ValueNotifier<bool>? colourBlind,
  }) : colourBlind = colourBlind ?? ValueNotifier(false) {
    game = BlockGame(
      controller: controller ?? controllerWith(),
      audio: audio,
      haptics: haptics,
      colourBlind: this.colourBlind,
      best: best,
      pixelRatio: 1,
      onGameOver: (_) => gameOvers++,
    );
  }

  final audio = FakeAudioService<Sfx>();
  final haptics = FakeHaptics();
  final ValueNotifier<bool> colourBlind;
  late final BlockGame game;
  int gameOvers = 0;
}

/// Finger position that puts [piece]'s top-left on cell ([row], [col]).
Offset fingerFor(BlockGame g, Piece piece, int row, int col) {
  final tl = g.layout.cellRect(row, col).topLeft;
  return Offset(
    tl.dx + piece.width * g.dragCell / 2,
    tl.dy + kDragFingerOffsetCells * g.layout.cell + piece.height * g.dragCell,
  );
}

/// Haptics other than the grid ticks while dragging.
List<HapticPattern> _impacts(_Harness h) =>
    h.haptics.played.where((p) => p != HapticPattern.selection).toList();

PlacementResult? dragTo(BlockGame g, int slot, int row, int col) {
  final piece = g.controller.state.tray[slot]!;
  final home = g.slots[slot].home;
  expect(g.startDrag(slot, Offset(home.x, home.y)), isTrue);
  g.moveDrag(fingerFor(g, piece, row, col));
  return g.endDrag();
}

void main() {
  final size = Vector2(400, 800);

  group('BlockGame drag and drop', () {
    late _Harness h;

    testWithGame<BlockGame>(
      'valid drop places the piece and plays place feedback',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final r = dragTo(game, 0, 7, 0);
        expect(r, isNotNull);
        expect(game.controller.state.board.at(7, 0), isNot(Board.emptyCell));
        expect(game.slots[0].view, isNull);
        expect(game.controller.state.score, 3);
        expect(h.audio.played.map((e) => e.$1), [Sfx.place]);
        expect(_impacts(h), [HapticPattern.light]);
        expect(game.ghost, isNull);
      },
    );

    testWithGame<BlockGame>(
      'ghost follows the drag and reports validity',
      () => (h = _Harness(
        controller: controllerWith(board: [..._empty.take(7), '0.......']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!;
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        game.moveDrag(fingerFor(game, piece, 3, 2));
        expect(game.ghost, (piece: piece, row: 3, col: 2, valid: true));
        game.moveDrag(fingerFor(game, piece, 7, 0));
        expect(game.ghost?.valid, isFalse);
        game.cancelDrag();
        // The 2x2 O hanging half off the bottom: a ghost, but invalid.
        final o = game.controller.state.tray[2]!;
        final oHome = game.slots[2].home;
        game.startDrag(2, Offset(oHome.x, oHome.y));
        game.moveDrag(fingerFor(game, o, 7, 3));
        expect(game.ghost, (piece: o, row: 7, col: 3, valid: false));
        game.cancelDrag();
        expect(game.ghost, isNull);
      },
    );

    testWithGame<BlockGame>(
      'a dragged piece is kept on screen',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        game.moveDrag(const Offset(5000, -5000));
        final v = game.drag!.view;
        expect(v.position.x + v.size.x / 2, lessThanOrEqualTo(size.x + 1e-6));
        expect(v.position.y - v.size.y / 2, greaterThanOrEqualTo(-1e-6));
      },
    );

    testWithGame<BlockGame>(
      'fast finger movement is accelerated; slow movement is 1:1',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final cell = game.layout.cell;
        final home = game.slots[0].home;
        final start = Offset(home.x, home.y);

        // Slow: 0.1 cell per 1/60 s = 6 cells/s... use 0.02 cell per frame.
        game.startDrag(0, start);
        var finger = start;
        final tl0 = game.drag!.topLeft;
        for (var i = 0; i < 20; i++) {
          game.update(1 / 60);
          finger += Offset(0, -0.02 * cell);
          game.moveDrag(finger);
        }
        final slowMoved = (game.drag!.topLeft - tl0).distance;
        expect(slowMoved, closeTo(0.4 * cell, 1e-6));
        game.cancelDrag();
        game.update(1);

        // Fast: 0.5 cell per frame = 30 cells/s, above full-gain speed.
        game.startDrag(0, start);
        finger = start;
        final tl1 = game.drag!.topLeft;
        for (var i = 0; i < 8; i++) {
          game.update(1 / 60);
          finger += Offset(0, -0.5 * cell);
          game.moveDrag(finger);
        }
        final fastMoved = (game.drag!.topLeft - tl1).distance;
        expect(
          fastMoved,
          greaterThan(4 * cell * (1 + (kDragGainMax - 1) * 0.8)),
        );
        expect(fastMoved, lessThanOrEqualTo(4 * cell * kDragGainMax + 1e-6));
      },
    );

    testWithGame<BlockGame>(
      'invalid drop returns home with the invalid sound',
      () => (h = _Harness(
        controller: controllerWith(board: [..._empty.take(7), '0.......']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final view = game.slots[0].view!;
        expect(dragTo(game, 0, 7, 0), isNull);
        expect(h.audio.played.map((e) => e.$1), [Sfx.invalid]);
        expect(game.controller.state.score, 0);
        game.update(1);
        expect(view.isAnimating, isFalse);
        expect(view.position, game.slots[0].home);
        expect(view.scale.x, closeTo(view.restScale, 1e-6));
        expect(view.isLifted, isFalse);
      },
    );

    testWithGame<BlockGame>(
      'release over the tray returns home silently',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final home = game.slots[1].home;
        game.startDrag(1, Offset(home.x, home.y));
        game.moveDrag(Offset(home.x, home.y + 5));
        expect(game.ghost, isNull);
        expect(game.endDrag(), isNull);
        expect(h.audio.played, isEmpty);
      },
    );

    testWithGame<BlockGame>(
      'only one drag at a time; empty slots and finished games ignore drags',
      () => (h = _Harness(
        controller: controllerWith(tray: ['mono', null, 'O']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        expect(game.startDrag(1, Offset.zero), isFalse);
        expect(game.startDrag(0, Offset.zero), isTrue);
        expect(game.startDrag(2, Offset.zero), isFalse);
        expect(game.drag?.slot, 0);
        game.cancelDrag();
        // No drag: these are no-ops.
        game.moveDrag(Offset.zero);
        expect(game.endDrag(), isNull);
      },
    );
  });

  group('BlockGame clears and effects', () {
    late _Harness h;

    testWithGame<BlockGame>(
      'a line clear spawns clearing blocks, floating text and clear feedback',
      () => (h = _Harness(
        controller: controllerWith(
          board: ['7.......', ..._empty.skip(1).take(6), '...12345'],
        ),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final r = dragTo(game, 0, 7, 0)!;
        expect(r.linesCleared, 1);
        await game.ready();
        final clearing = game.play.children.whereType<ClearingBlock>();
        expect(clearing, hasLength(8));
        expect(
          game.play.children.whereType<FloatingText>().map((t) => t.text),
          hasLength(1),
        );
        expect(h.audio.played.single, (Sfx.clear, 1.0));
        expect(_impacts(h), [HapticPattern.medium]);
        expect(game.play.isShaking, isFalse);

        // Effects finish and remove themselves.
        for (var i = 0; i < 20; i++) {
          game.update(0.1);
        }
        await game.ready();
        expect(game.play.children.whereType<TransientEffect>(), isEmpty);
      },
    );

    testWithGame<BlockGame>(
      'three lines at once shake the screen; pitch rises with the streak',
      () => (h = _Harness(
        controller: GameController.fromState(
          controllerWith(
            board: [
              '.1111111',
              '.1111111',
              '.1111111',
              '........',
              '........',
              '........',
              '........',
              '........',
            ],
          ).state.copyWith(streak: (streak: 2, missesSinceClear: 0)),
        ),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        // Tray slot 0 is I3_h; swap in a vertical I3 for this test.
        game.startGame(
          GameController.fromState(
            game.controller.state.copyWith(
              tray: [pieceById('I3_v'), null, null],
            ),
          ),
        );
        await game.ready();
        final r = dragTo(game, 0, 0, 0)!;
        expect(r.linesCleared, 3);
        expect(game.play.isShaking, isTrue);
        expect(h.audio.played.first.$2, closeTo(clearRate(2), 1e-9));
        game.update(kShakeDuration + 0.01);
        expect(game.play.isShaking, isFalse);
        expect(game.play.position, Vector2.zero());
      },
    );

    testWithGame<BlockGame>(
      'placing the last tray piece deals a new tray',
      () => (h = _Harness(
        controller: controllerWith(tray: ['mono', null, null]),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final r = dragTo(game, 0, 0, 0)!;
        expect(r.trayRefilled, isTrue);
        await game.ready();
        for (var i = 0; i < kTraySize; i++) {
          expect(game.slots[i].view?.piece, game.controller.state.tray[i]);
        }
      },
    );
  });

  group('BlockGame snapping tolerance and grid ticks', () {
    late _Harness h;

    testWithGame<BlockGame>(
      'held slightly over a block, the piece lands on the free spot next to it',
      () => (h = _Harness(
        controller: controllerWith(board: [..._empty.take(7), '...0....']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!; // I3_h
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        // Nearest is (7,1), which overlaps the block at (7,3); 0.45 cells
        // to the left is (7,0), which fits.
        final c = game.layout.cell;
        game.moveDrag(fingerFor(game, piece, 7, 1) - Offset(0.55 * c, 0));
        expect(game.ghost, (piece: piece, row: 7, col: 0, valid: true));
        expect(game.endDrag(), isNotNull);
        expect(game.controller.state.board.at(7, 0), isNot(Board.emptyCell));
      },
    );

    testWithGame<BlockGame>(
      'slightly past the board edge still lands on the edge',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!;
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        final c = game.layout.cell;
        game.moveDrag(fingerFor(game, piece, 3, 0) - Offset(0.6 * c, 0));
        expect(game.ghost, (piece: piece, row: 3, col: 0, valid: true));
      },
    );

    testWithGame<BlockGame>(
      'a tick per new landing cell, throttled, none for invalid spots',
      () => (h = _Harness(
        controller: controllerWith(board: [..._empty.take(7), '0.......']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!;
        final home = game.slots[0].home;
        int ticks() =>
            h.haptics.played.where((p) => p == HapticPattern.selection).length;
        // Big jumps between frames would otherwise count as fast swipes.
        game.dragAcceleration = false;

        game.startDrag(0, Offset(home.x, home.y));
        expect(ticks(), 0); // over the tray: no ghost
        game.update(0.1);
        game.moveDrag(fingerFor(game, piece, 2, 2));
        expect(ticks(), 1);
        game.update(0.1);
        game.moveDrag(fingerFor(game, piece, 2, 2) + const Offset(1, 1));
        expect(ticks(), 1, reason: 'same cell');
        game.update(0.1);
        game.moveDrag(fingerFor(game, piece, 2, 3));
        expect(ticks(), 2);
        // Same frame (no time passed): throttled.
        game.moveDrag(fingerFor(game, piece, 2, 4));
        expect(ticks(), 2);
        game.update(0.1);
        game.moveDrag(fingerFor(game, piece, 7, 0)); // invalid
        expect(game.ghost?.valid, isFalse);
        expect(ticks(), 2);
      },
    );
  });

  group('BlockGame clear preview', () {
    testWithGame<BlockGame>(
      'hovering where a drop completes a row previews that row',
      () => (_Harness(
        controller: controllerWith(
          board: ['7.......', ..._empty.skip(1).take(6), '...12345'],
        ),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!; // I3_h
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));

        game.moveDrag(fingerFor(game, piece, 3, 0));
        expect(game.ghost?.valid, isTrue);
        expect(game.clearPreview, isEmpty);

        game.moveDrag(fingerFor(game, piece, 7, 0));
        expect(game.clearPreview, {
          for (var c = 0; c < 8; c++) (row: 7, col: c),
        });

        game.cancelDrag();
        expect(game.clearPreview, isEmpty);
      },
    );

    testWithGame<BlockGame>(
      'row and column at once: crossing cell counted once',
      () => (_Harness(
        controller: controllerWith(
          board: [
            '.1111111',
            '1.......',
            '1.......',
            '1.......',
            '1.......',
            '1.......',
            '1.......',
            '1.......',
          ],
          tray: ['mono', 'O', null],
        ),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!;
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        game.moveDrag(fingerFor(game, piece, 0, 0));
        expect(game.clearPreview, hasLength(15));
        expect(game.clearPreview, contains((row: 0, col: 0)));
        // Dropping clears the preview along with the lines.
        expect(game.endDrag()!.linesCleared, 2);
        expect(game.clearPreview, isEmpty);
      },
    );

    testWithGame<BlockGame>(
      'no preview for an invalid ghost',
      () => (_Harness(
        controller: controllerWith(board: [..._empty.take(7), '0..12345']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final piece = game.controller.state.tray[0]!;
        final home = game.slots[0].home;
        game.startDrag(0, Offset(home.x, home.y));
        game.moveDrag(fingerFor(game, piece, 7, 0));
        expect(game.ghost?.valid, isFalse);
        expect(game.clearPreview, isEmpty);
      },
    );
  });

  group('BlockGame game over and best score', () {
    late _Harness h;
    const checker = [
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
      '0.0.0.0.',
      '.0.0.0.0',
    ];

    testWithGame<BlockGame>(
      'game over fires the callback after the delay',
      () => (h = _Harness(
        controller: controllerWith(board: checker, tray: ['mono', 'SQ3', null]),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        final r = dragTo(game, 0, 0, 1)!;
        expect(r.gameOver, isTrue);
        expect(h.audio.played.map((e) => e.$1), contains(Sfx.gameOver));
        expect(h.gameOvers, 0);
        expect(game.startDrag(1, Offset.zero), isFalse);
        game.update(kGameOverDelay / 2);
        expect(h.gameOvers, 0);
        game.update(kGameOverDelay);
        expect(h.gameOvers, 1);
        game.update(1);
        expect(h.gameOvers, 1);
      },
    );

    testWithGame<BlockGame>(
      'passing the best score celebrates once',
      () => (h = _Harness(best: 2)).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        dragTo(game, 0, 0, 0); // +3 -> 3 > best 2
        dragTo(game, 1, 2, 0); // +1, no second celebration
        final sounds = h.audio.played.map((e) => e.$1).toList();
        expect(sounds.where((s) => s == Sfx.newBest), hasLength(1));
        expect(h.haptics.played, contains(HapticPattern.success));
      },
    );

    testWithGame<BlockGame>(
      'no new-best celebration on the very first game (best 0)',
      () => (h = _Harness()).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        dragTo(game, 0, 0, 0);
        expect(h.audio.played.map((e) => e.$1), isNot(contains(Sfx.newBest)));
      },
    );

    testWithGame<BlockGame>(
      'startGame resets the board, tray and effects',
      () => (h = _Harness(
        controller: controllerWith(board: [..._empty.take(7), '...12345']),
      )).game,
      (game) async {
        game.onGameResize(size);
        await game.ready();
        dragTo(game, 0, 7, 0);
        await game.ready();
        game.startGame(
          GameController.newGame(mode: GameMode.classic, seed: 9),
          best: 50,
        );
        await game.ready();
        expect(game.best, 50);
        expect(game.controller.state.board.isEmpty, isTrue);
        expect(game.play.children.whereType<TransientEffect>(), isEmpty);
        for (var i = 0; i < kTraySize; i++) {
          expect(game.slots[i].view?.piece, game.controller.state.tray[i]);
        }
      },
    );
  });

  testWithGame<BlockGame>(
    'HUD shows a resumed game\'s score, best and streak before any move',
    () => _Harness(
      best: 1200,
      controller: GameController.fromState(
        controllerWith(score: 840).state
            .copyWith(streak: (streak: 2, missesSinceClear: 0)),
      ),
    ).game,
    (game) async {
      game.onGameResize(size);
      await game.ready();
      final texts = game.hud.children.whereType<TextComponent>().map(
        (t) => t.text,
      );
      expect(texts, containsAll(['840', 'Best 1200', 'Streak x3']));
    },
  );

  testWithGame<BlockGame>(
    'colour-blind setting re-renders the sprites',
    () => _Harness(colourBlind: _cb = ValueNotifier(false)).game,
    (game) async {
      game.onGameResize(size);
      await game.ready();
      expect(game.sprites.colourBlind, isFalse);
      _cb.value = true;
      expect(game.sprites.colourBlind, isTrue);
    },
  );
}

late ValueNotifier<bool> _cb;
