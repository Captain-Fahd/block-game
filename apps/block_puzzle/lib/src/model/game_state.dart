import 'package:meta/meta.dart';

import 'board.dart';
import 'piece.dart';
import 'pieces.dart';
import 'scoring.dart';

enum GameMode { classic, daily }

/// Everything needed to save a game and resume it identically.
@immutable
class GameState {
  GameState({
    required this.mode,
    required this.seed,
    required this.board,
    required List<Piece?> tray,
    required this.score,
    required this.streak,
    required this.rngState,
    this.placements = 0,
    this.linesCleared = 0,
    this.secondChanceUsed = false,
    this.isOver = false,
  }) : tray = List.unmodifiable(tray);

  factory GameState.fromJson(Map<String, dynamic> json) {
    final streak = json['streak'] as Map<String, dynamic>;
    return GameState(
      mode: GameMode.values.byName(json['mode'] as String),
      seed: json['seed'] as int,
      board: Board.fromJson(json['board'] as Map<String, dynamic>),
      tray: [
        for (final id in json['tray'] as List)
          id == null ? null : pieceById(id as String),
      ],
      score: json['score'] as int,
      streak: (
        streak: streak['streak'] as int,
        missesSinceClear: streak['misses'] as int,
      ),
      rngState: json['rng'] as int,
      placements: json['placements'] as int,
      linesCleared: json['linesCleared'] as int,
      secondChanceUsed: json['secondChanceUsed'] as bool,
      isOver: json['isOver'] as bool,
    );
  }

  static const int schemaVersion = 1;

  final GameMode mode;
  final int seed;
  final Board board;

  /// Tray slots; `null` once that slot's piece has been placed.
  final List<Piece?> tray;
  final int score;
  final StreakState streak;
  final int rngState;
  final int placements;
  final int linesCleared;
  final bool secondChanceUsed;
  final bool isOver;

  Iterable<Piece> get remainingPieces => tray.whereType<Piece>();

  GameState copyWith({
    Board? board,
    List<Piece?>? tray,
    int? score,
    StreakState? streak,
    int? rngState,
    int? placements,
    int? linesCleared,
    bool? secondChanceUsed,
    bool? isOver,
  }) => GameState(
    mode: mode,
    seed: seed,
    board: board ?? this.board,
    tray: tray ?? this.tray,
    score: score ?? this.score,
    streak: streak ?? this.streak,
    rngState: rngState ?? this.rngState,
    placements: placements ?? this.placements,
    linesCleared: linesCleared ?? this.linesCleared,
    secondChanceUsed: secondChanceUsed ?? this.secondChanceUsed,
    isOver: isOver ?? this.isOver,
  );

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'mode': mode.name,
    'seed': seed,
    'board': board.toJson(),
    'tray': [for (final p in tray) p?.id],
    'score': score,
    'streak': {'streak': streak.streak, 'misses': streak.missesSinceClear},
    'rng': rngState,
    'placements': placements,
    'linesCleared': linesCleared,
    'secondChanceUsed': secondChanceUsed,
    'isOver': isOver,
  };

  @override
  bool operator ==(Object other) =>
      other is GameState &&
      other.mode == mode &&
      other.seed == seed &&
      other.board == board &&
      _listEq(other.tray, tray) &&
      other.score == score &&
      other.streak == streak &&
      other.rngState == rngState &&
      other.placements == placements &&
      other.linesCleared == linesCleared &&
      other.secondChanceUsed == secondChanceUsed &&
      other.isOver == isOver;

  @override
  int get hashCode => Object.hash(
    mode,
    seed,
    board,
    Object.hashAll(tray),
    score,
    streak,
    rngState,
    placements,
    linesCleared,
    secondChanceUsed,
    isOver,
  );

  static bool _listEq(List<Piece?> a, List<Piece?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i]?.id != b[i]?.id) return false;
    }
    return true;
  }
}
