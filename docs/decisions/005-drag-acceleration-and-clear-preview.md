# 005. Drag acceleration and line-clear preview

Date: 2026-11-11
Status: accepted (from Omar's Phase 4 playtest)

## Context
Omar's first playtest feedback:
1. "The speed of the blocks when moving them feels sluggish. Add some acceleration to the movement once selected."
2. "If a move is going to take out a column/row then it should give the person a preview when hovering over that section."

The Phase 2 spec had the piece follow the finger 1:1 and only a landing ghost (no line preview). It also said the lift is "~1.15×". In practice the tray shows pieces at 0.55 of a cell and the lifted piece is drawn at board cell size, so the lift is a scale-up from tray size. The spec now says that.

## Decision
- **Drag acceleration.** The piece keeps its own position and moves by each finger movement times `dragGain(speed)`, where speed is a smoothed estimate in cells per second on the game clock. The gain is 1.0 up to `kDragAccelStartSpeed` (3 cells/s), eases (smoothstep) up to `kDragGainMax` (1.8) at `kDragAccelFullSpeed` (15 cells/s), and stays there above that. Slow adjustments stay exact; quick swipes cover the board with less finger travel. The piece is clamped to stay on screen. All numbers are in `constants.dart`.
- **Clear preview.** When the ghost is valid, the game computes which cells the drop would clear (place, then find full lines) only when the snap cell changes. The board draws those lines' existing blocks in the dragged piece's colour, draws the ghost cells in them at full opacity, and pulses a white glow (alpha 0.10–0.35 at 2.2 Hz) over the whole lines.

## Consequences
- A piece can lead the finger after a fast move. That's intended, but it means the gain values need Omar's feel check; tune `kDragGainMax` and the two speeds if it feels slippery or still slow.
- Autoplay (debug/profile tool) turns acceleration off, because it computes exact 1:1 finger paths.
- The preview costs one board copy and line scan per snap-cell change, which is negligible.
- Tests cover the gain curve, 1:1 slow drags, accelerated fast drags, the on-screen clamp, preview cells for a row and a row+column cross, no preview for invalid ghosts, and clearing the preview on drop and cancel. A golden image shows the preview.
