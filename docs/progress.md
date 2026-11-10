# Progress log

Newest entries at the top. One entry per session: what got done, what's next, blockers.

## 2026-11-11

### Done
- Checked commit `1bdbf05` (Phase 1 `game_core`) against the plan: format clean, `flutter analyze` no issues, 30 `game_core` tests and 94 block puzzle tests pass, and the commit contains no secrets. Push from this shell failed (no GitHub HTTPS credentials); Omar pushes himself.
- **Phase 1 acceptance run on a real phone** (DNP-NX9, Android API 37, connected over USB, so **P0.9 ticked**), using the `game_core/example` app:
  - Consent with no EEA debug setting: `canRequestAds=true`, no form.
  - Test interstitial shown and dismissed, `shown: true`.
  - Test rewarded played to "Reward granted", `earned: true` only after the reward.
  - EEA debug geography: the GDPR form appears, Consent gives `canRequestAds=true` and `privacyOptionsRequired=true`; the privacy options form opens from the Privacy button.
- **Bug fixed in `UmpConsentService.gather()`.** The 8 s timeout covered the time the consent form sat on screen as well as the network request. A player who took longer than 8 s on the form was left with `canRequestAds=false`, so no ads loaded that session and the app carried on behind the form. Now only the info-update request is time-limited, and the form is awaited until it's dismissed. Reproduced on the phone before the fix (`consent timed out` while the form was showing) and checked after it (form held 14 s, then Consent → ads initialised).
- The example app's "Ads initialised" line no longer prints when consent blocks ads.
- **Ticked:** P1.1, P1.2, P1.3, P1.6, P1.7, P1.10, P1.11, P1.12.

### Measured
- `game_core` line coverage is 57.3% overall: 100% for logger, storage, settings, haptics, house ads, ad ids and ad policy; low for the SDK wrappers (consent 11%, AdMob service 20%, crash reporting 21%, audio 23%), which only run against the real SDKs on a device. The ≥ 90% rule applies to model code, which is still at 98.8%.

### Partly done (not ticked)
- **P1.4 Audio, P1.5 Haptics:** code and fakes are done, but neither has been tried on the phone yet. That happens in P4.5, when the game has real sounds.
- **P1.8 Analytics, P1.9 Crash reporting:** code and no-op fakes are done; they need the Firebase project (P0.8) and `google-services.json` (P6.9) before they can be checked.

### Notes
- UMP debug geography and AdMob test ads only apply on a real phone when its **hashed device ID** is registered. Omar's phone ID is printed in logcat (`addTestDeviceHashedId(...)`). Pass it with `--dart-define=ADMOB_TEST_DEVICE_IDS=<id>` or put it in `env/test.json` (gitignored). Don't commit it.

### Next
- Phase 4 (Flame rendering and input), starting with P4.1.
- Blocked on Omar: P0.6–P0.8 accounts, P2.0 name pick.

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
