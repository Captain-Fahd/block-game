# 008. Name: Lantern Blocks

Date: 2026-11-11
Status: accepted (Omar's pick, P2.0)

## Context
P2.0 asked for 8 name proposals (docs/store/block_puzzle/names.md). Omar picked the recommended one and asked for "a few elements to make it suit the name more".

## Decision
- Name **Lantern Blocks**; Play store title **"Lantern Blocks: Block Puzzle"** (28 characters, keeps the searchable term).
- App id and Kotlin namespace `com.omarfahd.lanternblocks` (permanent once published). Launcher label "Lantern Blocks"; in-app title `kAppTitle`.
- The repo folder and Dart package stay `apps/block_puzzle` / `block_puzzle`: internal names, so renaming them would only add churn.
- Lantern-themed touches, all subtle and code-drawn (values in constants.dart):
  - a code-drawn lantern logo on Home (and later the basis of the app icon, P7.5);
  - a warm glow pooled behind the board;
  - a few faint lights drifting upward in the background;
  - clears release warm embers that rise and fade, instead of debris falling with gravity;
  - the line-clear preview glows warm amber instead of white.
  Colour-blind patterns and gameplay are unchanged.

## Consequences
- **Before purchase or publishing,** Omar should register lanternblocks.com and run a formal trademark search (IP Australia, USPTO; classes 9 and 41). Neither has been done; only .com availability and existing-game searches were checked.
- Changing the application id makes the Android build a different app from the earlier `com.omarfahd.blockpuzzle` test installs; local progress from those doesn't carry over (irrelevant before launch).
- Store listing, icon, feature graphic and privacy policy (Phases 7–8) use this name.
