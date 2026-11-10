import '../constants.dart';
import 'board.dart';
import 'piece.dart';
import 'pieces.dart';
import 'rng.dart';

/// Builds trays of pieces with weighted randomness and the fairness rule.
class PieceGenerator {
  PieceGenerator(this.rng, {List<Piece>? pieces, this.bands = kScoreBands})
    : pieces = pieces ?? kAllPieces;

  final SeededRng rng;
  final List<Piece> pieces;
  final List<ScoreBand> bands;

  ScoreBand bandFor(int score) {
    var band = bands.first;
    for (final b in bands) {
      if (score >= b.minScore) band = b;
    }
    return band;
  }

  /// Weighted pick from [candidates]. Each family's weight is split evenly
  /// across its orientations present in [candidates].
  Piece pick(List<Piece> candidates, ScoreBand band) {
    final familyCounts = <String, int>{};
    for (final p in candidates) {
      familyCounts[p.family] = (familyCounts[p.family] ?? 0) + 1;
    }
    final weights = [
      for (final p in candidates)
        (band.weights[p.family] ?? 0) / familyCounts[p.family]!,
    ];
    final total = weights.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return candidates[rng.nextInt(candidates.length)];
    var roll = rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll < 0) return candidates[i];
    }
    return candidates.last;
  }

  /// Generates a tray for [board]. Returns `null` when no piece in the whole
  /// set fits, meaning the game is over.
  ///
  /// Fairness: at least one piece fits. Retries [kFairnessRetries] times, then
  /// replaces one piece with the largest piece that fits.
  List<Piece>? nextTray(
    Board board, {
    required int score,
    bool firstTray = false,
  }) {
    final band = bandFor(score);
    final pool = firstTray
        ? pieces.where((p) => p.size <= kFirstTrayMaxPieceSize).toList()
        : pieces;

    List<Piece> tray = const [];
    for (var attempt = 0; attempt < kFairnessRetries; attempt++) {
      tray = [for (var i = 0; i < kTraySize; i++) pick(pool, band)];
      if (tray.any(board.anyFit)) return tray;
    }

    final fitting = pool.where(board.anyFit).toList();
    if (fitting.isEmpty) return null;
    final maxSize = fitting.map((p) => p.size).reduce((a, b) => a > b ? a : b);
    final largest = fitting.where((p) => p.size == maxSize).toList();
    final replacement = largest[rng.nextInt(largest.length)];
    final slot = rng.nextInt(kTraySize);
    return [...tray]..[slot] = replacement;
  }

  /// Second-chance tray: every piece fits the current board on its own.
  /// Returns `null` if nothing fits (board full), which can't happen in
  /// normal play because a full board always has full lines to clear.
  List<Piece>? secondChanceTray(Board board, {required int score}) {
    final fitting = pieces.where(board.anyFit).toList();
    if (fitting.isEmpty) return null;
    final band = bandFor(score);
    return [for (var i = 0; i < kTraySize; i++) pick(fitting, band)];
  }
}
