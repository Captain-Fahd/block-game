import '../constants.dart';

/// Streak state carried between placements.
typedef StreakState = ({int streak, int missesSinceClear});

const StreakState kInitialStreak = (streak: 0, missesSinceClear: 0);

/// Score breakdown for one placement.
typedef PlacementScore = ({
  int placementPoints,
  int linePoints,
  int multiplier,
  int boardClearBonus,
  int total,
  StreakState streakAfter,
});

/// Base points for clearing [lines] lines in one placement.
int lineClearPoints(int lines) {
  if (lines <= 0) return 0;
  final last = kLineClearPoints.length - 1;
  if (lines <= last) return kLineClearPoints[lines];
  return kLineClearPoints[last] + (lines - last) * kExtraLinePoints;
}

/// Scores one placement.
///
/// Streak rule: the multiplier is `1 + streak` where `streak` is the value
/// *before* this placement, so the first clear is ×1 and a clear on the
/// following placement is ×2. A clearing placement then increments the
/// streak; [kStreakResetAfterMisses] placements in a row without a clear
/// reset it to 0. (Interpretation recorded in docs/decisions/002.)
PlacementScore scorePlacement({
  required int cellsPlaced,
  required int linesCleared,
  required bool boardEmptyAfter,
  required StreakState streak,
}) {
  final placementPoints = cellsPlaced * kPointsPerCell;
  final multiplier = 1 + streak.streak;
  final linePoints = lineClearPoints(linesCleared) * multiplier;
  final bonus = linesCleared > 0 && boardEmptyAfter ? kBoardClearBonus : 0;

  final StreakState after;
  if (linesCleared > 0) {
    after = (streak: streak.streak + 1, missesSinceClear: 0);
  } else {
    final misses = streak.missesSinceClear + 1;
    after = misses >= kStreakResetAfterMisses
        ? kInitialStreak
        : (streak: streak.streak, missesSinceClear: misses);
  }

  return (
    placementPoints: placementPoints,
    linePoints: linePoints,
    multiplier: multiplier,
    boardClearBonus: bonus,
    total: placementPoints + linePoints + bonus,
    streakAfter: after,
  );
}
