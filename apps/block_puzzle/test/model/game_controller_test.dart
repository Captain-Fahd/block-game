import 'dart:convert';

import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/piece.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:block_puzzle/src/model/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Move = (int slot, int row, int col);

/// Deterministic bot: first slot, first valid position.
Move? firstMove(GameState s) {
  for (var slot = 0; slot < s.tray.length; slot++) {
    final p = s.tray[slot];
    if (p == null) continue;
    for (final pos in s.board.validPositions(p)) {
      return (slot, pos.row, pos.col);
    }
  }
  return null;
}

/// Plays to game over with [firstMove]; returns the move list.
List<Move> playOut(GameController g, {int maxMoves = 2000}) {
  final moves = <Move>[];
  while (!g.isOver && moves.length < maxMoves) {
    final m = firstMove(g.state)!;
    g.place(m.$1, m.$2, m.$3);
    moves.add(m);
  }
  return moves;
}

GameState stateWith(Board board, List<String?> tray, {int score = 0}) =>
    GameState(
      mode: GameMode.classic,
      seed: 1,
      board: board,
      tray: [for (final id in tray) id == null ? null : pieceById(id)],
      score: score,
      streak: kInitialStreak,
      rngState: 12345,
    );

void main() {
  test('new game: empty board, first tray small, score 0', () {
    final g = GameController.newGame(mode: GameMode.classic, seed: 9);
    expect(g.state.board.isEmpty, isTrue);
    expect(g.state.tray.length, 3);
    expect(g.state.remainingPieces.every((p) => p.size <= 3), isTrue);
    expect(g.state.score, 0);
    expect(g.isOver, isFalse);
  });

  test('placing empties the slot and refills after all three', () {
    final g = GameController.newGame(mode: GameMode.classic, seed: 9);
    final r1 = g.place(0, 0, 0);
    expect(g.state.tray[0], isNull);
    expect(r1.trayRefilled, isFalse);
    expect(g.state.score, r1.piece.size);
    expect(() => g.place(0, 4, 4), throwsStateError);
    g.place(1, 4, 0);
    final r3 = g.place(2, 0, 5);
    expect(r3.trayRefilled, isTrue);
    expect(g.state.tray.every((p) => p != null), isTrue);
    expect(g.state.placements, 3);
  });

  test('illegal moves throw', () {
    final g = GameController.newGame(mode: GameMode.classic, seed: 1);
    expect(() => g.place(5, 0, 0), throwsRangeError);
    expect(() => g.place(0, 8, 8), throwsStateError);
    expect(g.canPlace(0, 8, 8), isFalse);
    expect(g.canPlace(0, 0, 0), isTrue);
  });

  test('line clear, streak and board-clear bonus', () {
    final board = Board.fromRows([
      '1111111.',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
      '........',
    ]);
    final g = GameController.fromState(
      stateWith(board, ['mono', 'mono', 'I3_h']),
    );
    final r = g.place(0, 0, 7);
    expect(r.clearedRows, [0]);
    expect(r.clearedCols, isEmpty);
    expect(r.clearedCells.length, 8);
    expect(r.boardCleared, isTrue);
    expect(g.state.score, 1 + 10 + 300);
    expect(g.state.streak.streak, 1);
    expect(g.state.linesCleared, 1);
  });

  test('game over when no remaining piece fits; second chance once', () {
    final board = Board.fromRows([
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1..',
    ]);
    final g = GameController.fromState(stateWith(board, ['mono', 'O', 'SQ3']));
    final r = g.place(0, 0, 1);
    expect(r.gameOver, isTrue);
    expect(g.isOver, isTrue);
    expect(g.blockedPieces.map((p) => p.id), ['O', 'SQ3']);
    expect(() => g.place(1, 0, 0), throwsStateError);

    expect(g.canUseSecondChance, isTrue);
    g.useSecondChance();
    expect(g.isOver, isFalse);
    expect(g.state.secondChanceUsed, isTrue);
    expect(g.state.remainingPieces.length, 3);
    expect(g.state.remainingPieces.every(g.state.board.anyFit), isTrue);
    expect(g.blockedPieces, isEmpty);
    expect(g.canUseSecondChance, isFalse);
    expect(g.useSecondChance, throwsStateError);
  });

  test('game over detected right after a refill', () {
    // Last tray piece placed; the new tray is generated for a board where
    // only a mono fits, so the fallback must supply one and play continues.
    final board = Board.fromRows([
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1.1',
      '1.1.1.1.',
      '.1.1.1..',
    ]);
    final g = GameController.fromState(stateWith(board, [null, null, 'mono']));
    final r = g.place(2, 7, 7);
    expect(r.trayRefilled, isTrue);
    expect(g.isOver, isFalse);
    expect(g.state.remainingPieces.any(g.state.board.anyFit), isTrue);
  });

  test('replaying a recorded move list gives the same final score', () {
    final g1 = GameController.newGame(mode: GameMode.daily, seed: 20270115);
    final moves = playOut(g1);
    expect(g1.isOver, isTrue);
    expect(moves.length, greaterThan(5));

    final g2 = GameController.newGame(mode: GameMode.daily, seed: 20270115);
    for (final (slot, row, col) in moves) {
      g2.place(slot, row, col);
    }
    expect(g2.state, g1.state);
    expect(g2.state.score, g1.state.score);
  });

  test('serialise mid-game and resume to an identical game', () {
    final a = GameController.newGame(mode: GameMode.classic, seed: 4242);
    for (var i = 0; i < 10; i++) {
      final m = firstMove(a.state)!;
      a.place(m.$1, m.$2, m.$3);
    }
    final json = jsonEncode(a.state.toJson());
    final restored = GameState.fromJson(
      jsonDecode(json) as Map<String, dynamic>,
    );
    expect(restored, a.state);
    expect(restored.hashCode, a.state.hashCode);

    final b = GameController.fromState(restored);
    playOut(a);
    playOut(b);
    expect(b.state, a.state);
  });

  test('state equality notices tray differences', () {
    final s = stateWith(Board.empty(), ['mono', null, 'O']);
    expect(s == stateWith(Board.empty(), ['mono', null, 'O']), isTrue);
    expect(s == stateWith(Board.empty(), ['mono', 'O', null]), isFalse);
    expect(s == s.copyWith(tray: <Piece?>[null, null]), isFalse);
  });
}
