# Progress log

Newest entries at the top. One entry per session: what got done, what's next, blockers.

## 2026-11-10

### Done
- **P0.1** `flake.nix`: Flutter 3.47.4 / Dart 3.13.3 (nixpkgs), JDK 17, Android SDK platforms 35+36, build-tools 35.0.0+36.0.0, NDK 28.2.13676358 (what Flutter's Gradle plugin defaults to), CMake 3.22.1, emulator 37.2 + API 36 `google_apis_playstore` x86_64 image. aapt2 override in the shell hook (ADR 001). SDK `platform-tools` put first on PATH because the system also has an `adb`.
- **P0.2** `flutter doctor` has no Android errors. (It still prints "Some Android licenses not accepted" because the Nix store is read-only; builds aren't affected.) A throwaway `flutter create` app built a debug APK (AGP 9.1, Gradle 9.3) and ran on an API 36 emulator (AVD `bp_api36`). The app has been deleted. **Not yet run on a real phone (P0.9).**
- **P0.3** Repo scaffold: pub workspace (`packages/game_core`, `apps/block_puzzle`), shared lints, `.gitignore` with the secrets list, ADRs 000–002.
- **P0.4** `.github/workflows/ci.yml` (subosito/flutter-action, Flutter pinned to 3.47.4). Not run yet; that needs a first push.
- **Phase 2** spec copied to `apps/block_puzzle/SPEC.md`. Streak timing ambiguity → ADR 002 (proposed).
- **Phase 3 (P3.1–P3.7)** pure-Dart model: `Piece` + 35-piece set, immutable `Board`, `scorePlacement`, serialisable `SeededRng` (xorshift32), `PieceGenerator` (score bands, fairness rule plus fallback, small first tray, second-chance tray), `GameState`/`GameController` with JSON resume, `dailySeed`. 94 tests, **98.8% line coverage** on `lib/src`.

### Simulation (P3.7) — `dart run tool/simulate.dart --games 500 [--casual]`
| Bot | Median score | Median placements | Est. median length @3.5 s/move | Top game-over causes |
|---|---|---|---|---|
| Greedy (one-ply heuristic) | 2320 | 110 | 6.4 min | SQ3 55%, I5 15%, BL3 10% |
| Casual (random of top 3) | 456 | 38 | 2.2 min | SQ3 31%, BL3 13%, I5 13% |

Real casual play should fall between the two bots, which is inside the 3–6 min target. Weights stay as they are until on-device playtests (Phase 4 acceptance). If playtesters die early, lower `SQ3`/`BL3` in the easy band first, since they cause most game-overs.

### Next
- Phase 1 `game_core` services (logger, storage, settings, audio, haptics, consent, ads, analytics, crashlytics, review, theme).
- Blocked on Omar: P0.6–P0.9 accounts/device, P2.0 name pick (which sets the package id; interim app id is `com.omarfahd.blockpuzzle`).
