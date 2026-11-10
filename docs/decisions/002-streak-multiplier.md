# 002. Streak multiplier timing

Date: 2026-11-10
Status: Proposed (Omar to confirm)

## Context
The spec says "a placement that clears at least one line increments the streak … line clear points × (1 + streak)". It doesn't say whether the multiplier uses the streak before or after the increment.

## Decision
Use the streak *before* this placement. First clear ×1, second consecutive clear ×2, third ×3. Three placements in a row without a clear reset the streak to 0; one or two misses keep it.

## Consequences
- A single isolated clear scores its base points, which keeps early scores readable (10/30/60/100).
- The alternative (×2 on the first clear) would roughly double line points across the board; easy to switch in `lib/src/model/scoring.dart` if preferred.
