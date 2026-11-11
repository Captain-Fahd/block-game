# Progress log

Newest entries at the top. One entry per session: what got done, what's next, blockers.

## 2026-11-11 (Phase 6, part 1: ads)

### Done
- **Sound rework (before Phase 6):** Omar found the in-game sounds inconsistent and the line clear piercing. All sounds now share one soft mallet voice on C major pentatonic notes, peak-normalised; the clear is a warm low-mid strum, and streak pitch steps up musical intervals (max 1.5x; top frequency about 1.6 kHz instead of about 2.8 kHz). Omar: "sounds good". Also: subtle menu sounds via a `game_core` `UiSounds` hook, and no music at all (ADR 006).
- **P6.1:** `AdMobAdsService` wired with the block puzzle's `AdPolicy`. SDK initialised only after UMP consent.
  - Ad units: Google's sample units except in release builds with `env/prod.json`.
  - AdMob app id: a manifest placeholder, the sample id in debug/profile and `ADMOB_APP_ID` in release. Checked with aapt2 on debug, release-with-id and release-without-id APKs.
  - `UMP_DEBUG_EEA` dart-define for testing the consent form.
- **P6.2:** rewarded second chance. On Omar's phone: offered at game over when an ad is ready; the test ad played to the end; reward earned; game continued with a tray that fits.
- **P6.3:** interstitial on leaving Results (Play again / Home) with every cap: first 2 games free, 120 s gap (now persisted across restarts), not after games under 30 s, not after a rewarded ad in the same flow; logs `ad_interstitial_shown` with its trigger. On the phone: shown after Play again when eligible.
- **Banner (ADR 007, Omar's request):** one anchored adaptive banner at the bottom of Results only, its height reserved before it loads, clear of the buttons. Release builds show no banner without `ADMOB_BANNER_ID`. Checked on the phone.
- **P6.6 (code and tests, not ticked):** `ReviewPrompter` asks after a new best, never in the first session, at most every 30 days; no interstitial in that flow. Not checkable on a device until the app is installed from Play (internal testing, P9.2).
- **P6.7:** app-level tests for every interstitial cap, the trigger name, review rules and banner placement (`decideInterstitial` was already unit tested in `game_core`).
- **Build fix and CI:** one commit broke the Android Gradle build (Kotlin DSL resolved `java.util` against Gradle's `java` extension) while CI stayed green. Fixed, and CI now has a `build-android` job that builds a debug APK.
- Debug/profile `AUTOPLAY_FLOW`: the bot stops at game over so the real ad flow runs on a device.

### Measured
- Tests: 187 block puzzle, 34 game_core, all passing; analyzer clean; Android debug and release builds compile.

### Notes
- The emulator overloaded (load average about 14, system services restarted) during a long run, so the ad checks moved to Omar's phone. Long waits now run in the background instead of blocking.
- The app was once removed from recents and reopened mid-test; logs show no crash.

### Next
- P2.0: propose 8 names.
- Blocked on Omar: P0.6 Play Console, P0.7 AdMob account, P6.8 AdMob app + **three** units (interstitial, rewarded, banner) + GDPR/US consent messages, P0.8/P6.9 Firebase + `google-services.json` (for P6.4 analytics and P6.5 Crashlytics).

## 2026-11-11 (Phase 5)

### Done
- **Phase 4 acceptance:** Omar playtested over three rounds of feedback (drag acceleration, line-clear preview, tolerant snapping plus grid haptics, gentler acceleration) and signed off ("feels good now").
- **P5.3 Persistence:** `ProgressStore` handles best scores per mode, today's daily best, games played, the daily streak (consecutive days, kept the next day, reset after a missed day; a daily that ends after midnight counts for its seeded date), the tutorial flag, and one saved game per mode (finished, corrupt, wrong-schema, wrong-mode and stale-daily saves are discarded). The game saves after every placement and when the app is backgrounded. Settings were already persisted by `game_core`.
- **P5.1 Screens:**
  - Home: Play, or Continue (with score) plus New game; Daily challenge or Continue daily; best, today's best and streak; Settings.
  - Game: pause button.
  - Results: score, best, new-best badge, daily streak, Play again, Home.
  - Back from Game pauses (never leaves mid-game); back from Home exits.
- **P5.2 Overlays:** Pause (Resume / Restart / Home) and game over ("No moves left", plus the second-chance offer only when a rewarded ad is ready, then Results). Coming back from the background shows Pause.
- **P5.4 Daily:** today's seed, separate bests, streak, resume of today's daily only.
- **P5.5 Tutorial:** 3 scripted steps (place a block, fill a row, fill a column) with pulsing target outlines. One piece at a time (other tray slots hidden, so no refill), a miss resets the step, skippable. Logs `tutorial_complete` with a skipped flag. No HUD and no ads.
- **P5.6 Settings:**
  - Sound, music, vibration, colour-blind patterns.
  - Privacy options (only when UMP says they're required).
  - Privacy policy link (only when `PRIVACY_POLICY_URL` is set).
  - How to play, credits and licences (Nunito OFL registered from `game_core`), version.
- **P5.7 Tests:** widget tests for every screen and flow (21), and an on-device integration test that plays a whole scripted Classic game end to end with `FakeAdsService` (passes on the API 36 emulator: 14 moves, score 87).
- **Acceptance (offline):** on the emulator in airplane mode, a cold launch reached Home in about 2 s (debug build); the consent request failed cleanly in the background and play was unaffected.
- Startup: consent is gathered after the first frame and never awaited before UI; ads initialise only after consent. Ads stay `FakeAdsService` with no rewarded ad ready until P6.1, so no second-chance offer appears yet (per spec). Analytics events fire through `NoopAnalytics` until P6.4.
- NixOS: Gradle 9 rejected the read-only `:integration_test` SDK plugin project. `settings.gradle.kts` now uses a writable copy (ADR 001 addendum).

### Measured
- Tests: 174 block puzzle (model, layout, game, goldens, data, UI) plus 1 integration, and 30 `game_core`. Model line coverage 99.4%; whole app 91.0%.

### Notes and decisions
- One saved game per mode (the spec said "a saved game"); a saved Daily is only resumable on its own date.
- No music (ADR 006): the Music toggle has been removed from Settings.
- The app title is the working title "Block Puzzle" until P2.0.

### Next
- Phase 6: wire AdMob (P6.1), rewarded second chance (P6.2), capped interstitials on Results (P6.3), Firebase analytics and Crashlytics (P6.4/6.5), review prompt (P6.6).
- Blocked on Omar: P0.6–P0.8 accounts, P6.8 AdMob units and consent messages, P6.9 `google-services.json`, and P2.0 name pick.

## 2026-11-11 (Phase 4)

### Done
- **P4.1** `BlockGame` (FlameGame) with board, tray and HUD. `GameLayout` is pure maths with unit tests for 360x640, tall phones, short wide screens, tablets (letterboxed at 520 dp) and safe-area insets. Checked on Omar's phone (1280x2800, 120 Hz).
- **P4.2** Blocks are drawn once per colour into a `ui.Image` (rounded square, darker bottom edge, top highlight, plus a pattern in colour-blind mode) and copied each frame. The empty well and grid are recorded once as a `Picture`. Shading blends towards black/white; HSL lightness made violet and red edges look harsh on the phone.
- **P4.3** Drag: the piece scales up from tray size (0.55 of a cell) to board size, sits 1.5 cells above the finger, shows a ghost (translucent if valid, red on empty cells if not), snaps within half a cell, or eases back to the tray. Tray pieces use one tween of their own instead of Flame effects: an effect added in the same frame isn't mounted yet, so a quick tap could leave lift and return fighting over the scale.
- **P4.4** Clear: cells flash white in a sweep outwards from the placed piece, then shrink into particle bursts. Floating score (with multiplier), "Board clear!", screen shake on 3+ lines, and a pulsing streak indicator. Checked on the phone with a screen recording.
- **P4.5** Sound and haptics through `game_core`: place (light), clear (medium, pitch +6% per streak step up to 1.6x), invalid drop, game over, new best (success, once per game). Sounds are generated by `tool/make_sfx.dart` (ADR 004, instead of Kenney packs). The phone's audio logs show playback through the speaker; nobody has listened to them yet.
- **P4.6** Golden tests at 360x640: empty, mid-game, valid ghost, invalid ghost, colour-blind.
- `main.dart` is a Phase 4 shell: straight into a Classic game, best score saved, and a minimal "No moves left / Play again" panel. Phase 5 replaces it.
- Debug/profile-only `--dart-define=AUTOPLAY=true`: a greedy bot plays through the normal drag path, and frame-time percentiles are logged. Used for the effect and performance checks; off in release.
- **Bug fixed:** the HUD showed 0 (no best, no streak) until the first move when a game started from saved state, because the first refresh ran inside `onLoad`, where `isLoaded` is still false. Test added.
- AdMob sample app id added to the manifest; the ads plugin crashes at startup without one. The real id comes with P6.1.
- Tests: 122 block puzzle (model 94, layout 9, game 14, golden 5) and 30 `game_core`, all passing.

### Measured
- The phone's display runs at **120 Hz**, so the frame budget is 8.3 ms.
- Debug build with autoplay: frame p50 5.6–6.9 ms, p95 about 10 ms (debug is much slower than profile).
- Profile build (autoplay, 120 Hz, frames logged in batches of about 300):
  - **Before fixes:** spikes of 30–49 ms (1–5 per batch), and after about 70 s a slowdown (p50 9.4 ms, 46 of 301 frames over 16.7 ms). A muted run had no spikes and no slowdown, so audio was the cause: `FlameAudio.play` creates and loads a new player for every effect and never disposes it.
  - **After the voice pool** (`game_core` `FlameAudioService`: 3 low-latency players per effect, created at preload and reused): 90 s with sound on, every batch after the first has max ≤ 17.5 ms and p95 10.4–12.1 ms. Raster p95 is 6.2–7.5 ms, there's no slowdown, and component counts stay at 18–38.
  - **First clear:** the old pre-warm was a no-op (its "invisible" block skipped all drawing). The new `Prewarm` component draws every effect path (alpha sprites, flash, particle, floating text at all three sizes with shadow and saveLayer) at near-zero opacity for 3 frames. Before: 2 frames of 17–21 ms on or just after the first clear. After: no slow frame around the first clear in the 2 cold starts where it fell inside the logged window.
  - **Remaining:** 1–2 slow frames in the first frames after launch (GPU setup, before input is possible), and a rare isolated ~19 ms frame (about 1 in 1,000) not tied to clears, probably CPU clock ramp-up.

- **P4.7 ticked** (see Measured).

### Playtest feedback round 1 (Omar)
- "Moving blocks feels sluggish" → speed-based **drag acceleration** (1:1 when slow, up to 1.8x for quick swipes; piece kept on screen).
- "Preview rows/columns a move would clear" → **clear preview**: those lines show in the dragged piece's colour with a pulsing glow. Checked on the phone in a screen recording.
- Both recorded in ADR 005; SPEC.md updated. The normal build with both changes is installed on the phone.

### Playtest feedback round 2 (Omar)
- "Snapping is too strict" → **tolerant snap**: if the nearest cell doesn't fit, use the closest fitting spot within 0.9 cells.
- "Subtle haptics when moving along the grid" → **selection tick** on each new valid landing cell, throttled to 35 ms. New `HapticPattern.selection` in `game_core`.
- ADR 005 round 2; SPEC.md updated. Tests: 140 block puzzle, 30 game_core. New build installed on the phone.

### Playtest feedback round 3 (Omar)
- "Too quick when swiping quickly" → drag gain max 1.8 → 1.4, full-gain speed 15 → 20 cells/s (ADR 005 round 3).

### Not done
- **Phase 4 acceptance:** Omar plays 5 games and gives feedback on feel (drag offset, sizes, sounds, shake), which I apply before Phase 5.

### Next
- Omar's 5-game playtest. A normal profile build without autoplay is installed on his phone. Apply his feedback, then start Phase 5.
- Then Phase 5 (screens, overlays, persistence, daily, tutorial, settings).

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
