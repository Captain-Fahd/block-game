/// Tunable values for the block puzzle. Every number in the game spec lives
/// here so tuning never touches logic.
library;

// --- Board ---------------------------------------------------------------
const int kBoardSize = 8;
const int kTraySize = 3;

// --- Scoring -------------------------------------------------------------
const int kPointsPerCell = 1;

/// Points for clearing N lines in one placement (index = N). Beyond the table,
/// each extra line adds [kExtraLinePoints].
const List<int> kLineClearPoints = [0, 10, 30, 60, 100];
const int kExtraLinePoints = 50;

/// Placements in a row without a clear that reset the streak to 0.
const int kStreakResetAfterMisses = 3;

const int kBoardClearBonus = 300;

// --- Piece generation ----------------------------------------------------
const int kFairnessRetries = 20;
const int kFirstTrayMaxPieceSize = 3;

/// Score bands. A score >= the band's `minScore` uses that band's weights.
/// Weights are per piece family; each orientation in a family shares the
/// family weight equally, so adding orientations doesn't skew odds.
class ScoreBand {
  const ScoreBand(this.name, this.minScore, this.weights);
  final String name;
  final int minScore;
  final Map<String, double> weights;
}

const List<ScoreBand> kScoreBands = [
  ScoreBand('easy', 0, {
    'mono': 6,
    'domino': 8,
    'I3': 9,
    'I4': 7,
    'I5': 3,
    'L3': 10,
    'L4': 7,
    'J4': 7,
    'T4': 6,
    'S4': 4,
    'Z4': 4,
    'O': 9,
    'SQ3': 2,
    'BL3': 3,
  }),
  ScoreBand('normal', 1500, {
    'mono': 3,
    'domino': 5,
    'I3': 8,
    'I4': 8,
    'I5': 5,
    'L3': 9,
    'L4': 8,
    'J4': 8,
    'T4': 7,
    'S4': 5,
    'Z4': 5,
    'O': 8,
    'SQ3': 4,
    'BL3': 5,
  }),
  ScoreBand('hard', 5000, {
    'mono': 1,
    'domino': 3,
    'I3': 7,
    'I4': 8,
    'I5': 7,
    'L3': 7,
    'L4': 8,
    'J4': 8,
    'T4': 8,
    'S4': 6,
    'Z4': 6,
    'O': 7,
    'SQ3': 6,
    'BL3': 7,
  }),
];

/// Number of distinct block colours (matches the theme palette).
const int kColourCount = 8;
