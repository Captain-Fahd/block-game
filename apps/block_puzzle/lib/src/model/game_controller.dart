import '../constants.dart';
import 'board.dart';
import 'game_state.dart';
import 'piece.dart';
import 'piece_generator.dart';
import 'rng.dart';
import 'scoring.dart';

/// What happened in one placement, for animations, sound and analytics.
class PlacementResult {
  const PlacementResult({
    required this.piece,
    required this.row,
    required this.col,
    required this.clearedRows,
    required this.clearedCols,
    required this.clearedCells,
    required this.score,
    required this.trayRefilled,
    required this.gameOver,
  });

  final Piece piece;
  final int row;
  final int col;
  final List<int> clearedRows;
  final List<int> clearedCols;
  final Set<CellOffset> clearedCells;
  final PlacementScore score;
  final bool trayRefilled;
  final bool gameOver;

  int get linesCleared => clearedRows.length + clearedCols.length;
  bool get boardCleared => score.boardClearBonus > 0;
}

/// Runs the rules. Holds the current [GameState]; every change produces a
/// new immutable state, so saving is just `state.toJson()`.
class GameController {
  GameController._(this._state, this._rng) : _generator = PieceGenerator(_rng);

  /// Starts a new game. The first tray only contains pieces of size <= 3.
  factory GameController.newGame({required GameMode mode, required int seed}) {
    final rng = SeededRng(seed);
    final board = Board.empty();
    final generator = PieceGenerator(rng);
    final tray = generator.nextTray(board, score: 0, firstTray: true)!;
    final state = GameState(
      mode: mode,
      seed: seed,
      board: board,
      tray: tray,
      score: 0,
      streak: kInitialStreak,
      rngState: rng.state,
    );
    return GameController._(state, rng);
  }

  /// Resumes a saved game exactly, including the RNG position.
  factory GameController.fromState(GameState state) =>
      GameController._(state, SeededRng.fromState(state.rngState));

  GameState _state;
  final SeededRng _rng;
  final PieceGenerator _generator;

  GameState get state => _state;
  bool get isOver => _state.isOver;
  bool get canUseSecondChance => _state.isOver && !_state.secondChanceUsed;

  bool canPlace(int slot, int row, int col) {
    final piece = _pieceAt(slot);
    return piece != null &&
        !_state.isOver &&
        _state.board.canPlace(piece, row, col);
  }

  /// Places the piece in tray [slot] with its top-left at ([row], [col]).
  /// Throws [StateError] if the move is illegal.
  PlacementResult place(int slot, int row, int col) {
    if (_state.isOver) throw StateError('game is over');
    final piece = _pieceAt(slot);
    if (piece == null) throw StateError('tray slot $slot is empty');

    var board = _state.board.place(piece, row, col);
    final lines = board.findFullLines();
    final cleared = board.cellsIn(lines);
    board = board.clearLines(lines);
    final linesCleared = lines.rows.length + lines.cols.length;

    final score = scorePlacement(
      cellsPlaced: piece.size,
      linesCleared: linesCleared,
      boardEmptyAfter: board.isEmpty,
      streak: _state.streak,
    );
    final newScore = _state.score + score.total;

    var tray = [..._state.tray]..[slot] = null;
    var refilled = false;
    var over = false;
    if (tray.every((p) => p == null)) {
      final next = _generator.nextTray(board, score: newScore);
      refilled = true;
      if (next == null) {
        over = true;
      } else {
        tray = next;
      }
    }
    if (!over) {
      over = !tray.whereType<Piece>().any(board.anyFit);
    }

    _state = _state.copyWith(
      board: board,
      tray: tray,
      score: newScore,
      streak: score.streakAfter,
      rngState: _rng.state,
      placements: _state.placements + 1,
      linesCleared: _state.linesCleared + linesCleared,
      isOver: over,
    );

    return PlacementResult(
      piece: piece,
      row: row,
      col: col,
      clearedRows: lines.rows,
      clearedCols: lines.cols,
      clearedCells: cleared,
      score: score,
      trayRefilled: refilled,
      gameOver: over,
    );
  }

  /// Rewarded second chance: replaces the tray with 3 pieces that each fit
  /// the current board. Allowed once per game, only at game over.
  void useSecondChance() {
    if (!canUseSecondChance) throw StateError('second chance not available');
    final tray = _generator.secondChanceTray(_state.board, score: _state.score);
    if (tray == null) throw StateError('no piece fits the board');
    _state = _state.copyWith(
      tray: tray,
      rngState: _rng.state,
      secondChanceUsed: true,
      isOver: false,
    );
  }

  /// Pieces left in the tray when the game ended (the "cause" of game over).
  List<Piece> get blockedPieces =>
      _state.isOver ? _state.remainingPieces.toList() : const [];

  Piece? _pieceAt(int slot) {
    if (slot < 0 || slot >= kTraySize) {
      throw RangeError.range(slot, 0, kTraySize - 1, 'slot');
    }
    return _state.tray[slot];
  }
}
