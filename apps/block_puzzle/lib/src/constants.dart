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

// --- Layout (logical pixels unless noted) --------------------------------
/// Widest the play area gets; wider screens (tablets) are letterboxed.
const double kMaxPlayWidth = 520;

/// Horizontal margin around the board.
const double kPlayMargin = 16;

/// Height reserved above the board for score, best and streak.
const double kHudHeight = 112;

/// Gap between the board and the tray, in board cells.
const double kTrayGapCells = 0.6;

/// Height of the tray area, in board cells.
const double kTrayHeightCells = 3.4;

/// Tray pieces are drawn at this fraction of the board cell size.
const double kTrayCellScale = 0.55;

/// Board well padding around the grid, in board cells.
const double kBoardPaddingCells = 0.12;

/// Gap between neighbouring blocks, as a fraction of a cell.
const double kBlockGapFraction = 0.06;

// --- Drag and drop -------------------------------------------------------
/// While dragging, a piece is drawn at board cell size times this. The tray
/// shows pieces smaller (kTrayCellScale), so lifting reads as a scale-up.
const double kDragCellScale = 1.0;

/// Gap between the finger and the bottom edge of a dragged piece, in cells,
/// so the finger doesn't cover it.
const double kDragFingerOffsetCells = 1.5;

/// Drag acceleration: a dragged piece moves by the finger's movement times
/// a gain that depends on finger speed (cells per second), like pointer
/// acceleration. Slow, precise moves stay 1:1; quick swipes go further.
const double kDragGainMin = 1.0;
const double kDragGainMax = 1.4;

/// Finger speed (cells/s) where acceleration starts, and where it reaches
/// [kDragGainMax]. Eased in between.
const double kDragAccelStartSpeed = 3;
const double kDragAccelFullSpeed = 20;

/// Smoothing for the finger-speed estimate (0..1, higher = more responsive).
const double kDragSpeedSmoothing = 0.5;

/// How far (in cells) a dragged piece may be from a cell and still snap.
const double kSnapThresholdCells = 0.5;

/// If the nearest cell doesn't fit, the piece snaps to the closest position
/// that does fit within this distance (in cells) of where it is held, so
/// being slightly off still lands.
const double kSnapToleranceCells = 0.9;

/// While dragging, a subtle haptic tick when the landing cell changes, at
/// most once per this many seconds.
const double kGridTickMinInterval = 0.035;

/// Seconds for a lifted piece to scale up / a dropped piece to fly home.
const double kLiftDuration = 0.08;
const double kReturnDuration = 0.18;

/// Seconds for a newly dealt tray piece to pop in.
const double kDealDuration = 0.22;

// --- Clear preview (while dragging) ------------------------------------
/// When a valid drop would complete lines, those lines' blocks show in the
/// dragged piece's colour with a pulsing white glow between these alphas.
const double kClearPreviewGlowMin = 0.10;
const double kClearPreviewGlowMax = 0.35;
const double kClearPreviewPulseHz = 2.2;

// --- Clear feedback ------------------------------------------------------
const double kClearFlashDuration = 0.10;
const double kClearShrinkDuration = 0.22;
const int kParticlesPerCell = 5;
const double kParticleLifespan = 0.55;

/// Particle launch speed and gravity, in cells per second (squared).
const double kParticleSpeedCells = 6;
const double kParticleGravityCells = 18;

/// Screen shake when at least this many lines clear at once.
const int kShakeMinLines = 3;
const double kShakeDuration = 0.28;

/// Peak shake offset, in cells.
const double kShakeAmplitudeCells = 0.12;

const double kFloatingScoreDuration = 0.9;

/// How far the floating score text rises, in cells.
const double kFloatingScoreRiseCells = 1.4;
const double kStreakPulseScale = 1.35;
const double kStreakPulseDuration = 0.25;

/// Delay before the game-over callback, so the last animation can finish.
const double kGameOverDelay = 0.6;

// --- Sound and haptics ---------------------------------------------------
/// Clear sound pitch rises by this much per streak step, up to the cap.
const double kClearPitchStep = 0.06;
const double kClearPitchMax = 1.6;
