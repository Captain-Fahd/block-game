# Block puzzle — game design spec

Copied from PLAN.md Phase 2 on 2026-11-10. This file is the source of truth for game rules; log changes in docs/decisions/.


Classic placement block puzzle. Original name and visuals — no borrowing from existing titles.

## P2.0 Naming [Claude Code proposes, OMAR picks]

- [ ] Propose 8 names. Each must contain a searchable term ("block puzzle", "blocks") in the store title, not match an existing game's name, and have a free `.com` or at least no obvious trademark clash. Omar picks one. Package id: `com.<omar's chosen prefix>.<name>`.

## Rules

- **Board:** 8×8 grid.
- **Tray:** 3 pieces offered at a time. The player drags any piece onto the board. When all 3 are placed, a new tray of 3 is generated.
- **No rotation.** Pieces are placed as shown.
- **Clearing:** after each placement, every full row and every full column clears at the same time. A cell in both a full row and a full column counts once.
- **Game over:** when no remaining tray piece fits anywhere on the board.
- **Piece set** (each orientation is a separate piece definition):
  - Mono (1), domino (2: H/V), I3 (2), I4 (2), I5 (2)
  - Small corner L3 (4 rotations), L4 (4) and J4 (4), T4 (4), S4/Z4 (2 each)
  - O 2×2, big square 3×3, big corner 3×3 L (4 rotations)

## Scoring (all values in `constants.dart`)

- +1 per cell placed.
- Line clear points by number of lines cleared in one placement: 1 → 10, 2 → 30, 3 → 60, 4 → 100, each extra line +50.
- **Streak:** a placement that clears at least one line increments the streak; 3 placements in a row without a clear reset it to 0. Line clear points × (1 + streak).
- **Board clear bonus:** +300 when the board is empty after a clear.

## Piece generation

- Weighted random from the piece set, using the injected seeded RNG.
- Weights shift with score bands (easy → normal → hard): fewer monos and dominos, more 3×3 and I5 as score rises. Bands and weights in `constants.dart`.
- **Fairness rule:** when generating a tray, at least one of the 3 pieces must fit the current board. Retry up to 20 times; if still none fit, replace one piece with the largest piece that does fit. If nothing at all fits, the game is over.
- The first tray of every game contains only pieces of size ≤ 3.

## Modes

- **Classic:** endless, best score saved.
- **Daily challenge:** seed derived from the local date (`yyyymmdd`), so every player gets the same sequence that day. Separate best score and a streak of days played. Local only, no server.

## Rewarded "second chance"

- Offered once per game at game over, only if a rewarded ad is ready.
- Reward: the tray is replaced with 3 pieces that are each guaranteed to fit the current board.
- If the player declines or the ad fails, go straight to results.

## Ad placement and caps (initial values in `constants.dart`)

- Interstitial: after the results screen when the player taps "Play again" or "Home".
  - Never in the first 2 games of a fresh install.
  - At least 120 s since the last interstitial.
  - Skip if the game lasted under 30 s.
  - Skip if a rewarded ad was watched in the same game-over flow.
- Banner: none at launch. (Revisit after launch on the home screen only, if retention data supports it.)
- No ads in the tutorial.

## Feel ("juice") — code-drawn

- Blocks: rounded squares with a subtle top highlight and darker bottom edge, drawn on `Canvas`; 7–8 colours from the theme palette; optional pattern overlay per colour for colour-blind mode.
- Drag: piece lifts and scales up from tray size to board cell size, rendered above the finger (configurable offset ~1.5 cells) so the finger doesn't cover it. Ghost preview on the board shows where it will land; red tint or no ghost when it doesn't fit.
- Drag acceleration (ADR 005): the piece moves by the finger's movement times a speed-based gain: 1:1 for slow, precise moves, easing up to 1.4× for quick swipes. The piece always stays on screen.
- Clear preview (ADR 005): while the ghost is valid and the drop would complete rows/columns, those lines' blocks show in the dragged piece's colour with a pulsing glow.
- Snap: piece snaps to the nearest cell if it fits; otherwise to the closest fitting position within 0.9 cells of where it's held (ADR 005), so being slightly off still lands. If nothing fits, it returns to the tray with an ease-out animation.
- Grid haptics (ADR 005): a subtle selection tick each time the valid landing cell changes while dragging (at most every 35 ms).
- Clear: cleared cells flash, shrink and burst into particles; short screen shake on 3+ lines; floating score text; streak counter pulses.
- Sound: place, clear (pitch rises with streak), invalid drop, game over, new best. Generated in code by `tool/make_sfx.dart` (ADR 004; replaces the Kenney packs).
- Menu sounds (ADR 004): a soft tick on button / row / icon taps and a small blip on switches (higher for on, lower for off), quieter than gameplay sounds; off with the Sound effects setting.
- Haptics: light on place, medium on clear, success on new best.

## Screens

Home (Classic, Daily, Settings, best score) → Game → Game over (second-chance offer) → Results (score, best, "Play again", "Home") ; Settings (sound, haptics, colour-blind patterns, privacy options, privacy policy link, credits/licences, version).

## Tutorial

First launch only: 3 scripted steps on a preset board (drag a piece; complete a row; complete a column). Skippable. Fires `tutorial_complete`.

## Resume

Save the full game state (board, tray, score, streak, RNG state, mode) on every placement and on `AppLifecycleState.paused`. Offer "Continue" on Home if a saved game exists.

## Clarifications (see ADRs)

- Streak multiplier uses the streak value *before* the placement: the first clear is ×1, a clear on the next placement ×2, and so on (ADR 002).
- The board-clear bonus applies only when the placement cleared at least one line (an empty board can't otherwise occur after a placement).
