# PLAN.md — Execution Plan

Phased plan for building and publishing ad-supported Android games with Flutter + Flame. Game 1 (block puzzle) is specified in full; games 2 and 3 are outlined at the end and get their own detailed spec once game 1 is live.

Rules for using this plan are in `CLAUDE.md`. Tick boxes as tasks finish. **[OMAR]** marks work only Omar can do.

Target: game 1 in closed testing by early January 2027 and live on Play by late January 2027.

---

## Platform facts this plan relies on (checked Nov 2026)

- New apps and updates must target **Android 16 (API 36)** from 31 Aug 2026.
- **New personal Play developer accounts** (created after 13 Nov 2023) must run a closed test with **at least 12 testers opted in for 14 continuous days** before production access. **Organisation accounts are exempt.** Omar already has an ABN and a D-U-N-S number, so an organisation account is an option (decision P0.5).
- `google_mobile_ads` (Google's official plugin) is at 9.x; Flame stable is 1.3x. Check pub.dev for current versions when scaffolding.
- AdMob requires an `app-ads.txt` file on the developer website listed in the Play listing.

If any of these look different when you check, update this section and tell Omar.

---

## Target repo layout

```
f2p-games/
├── CLAUDE.md
├── PLAN.md
├── flake.nix / flake.lock
├── pubspec.yaml                 # pub workspace root
├── analysis_options.yaml
├── packages/
│   └── game_core/               # shared: ads, consent, analytics, storage, audio, haptics, review, theme, logger
├── apps/
│   └── block_puzzle/
│       ├── lib/src/model/       # pure Dart game logic
│       ├── lib/src/game/        # Flame components
│       ├── lib/src/ui/          # Flutter screens and overlays
│       ├── lib/src/constants.dart
│       ├── assets/audio/  assets/fonts/
│       ├── env/example.json     # committed; env/test.json and env/prod.json gitignored
│       ├── test/  integration_test/
│       └── tool/                # icon, feature graphic and screenshot generators
├── docs/
│   ├── progress.md
│   ├── decisions/
│   ├── store/block_puzzle/      # listing text, data-safety draft, screenshots
│   └── legal/privacy-policy.md
└── .github/workflows/ci.yml     # analyze + test on push
```

---

## Phase 0 — Environment and accounts

### Claude Code tasks

- [x] **P0.1 Nix dev shell.** Create `flake.nix` with a `devShells.x86_64-linux.default` containing Flutter (nixpkgs `flutter`), JDK 17, and an Android SDK from `androidenv.composeAndroidPackages` with platforms 35 and 36, matching build-tools, platform-tools, the NDK and CMake versions Flutter's Gradle plugin asks for, and the emulator with an x86_64 `google_apis_playstore` API 36 image. Set `allowUnfree = true` and `android_sdk.accept_license = true`. Export `ANDROID_HOME`, `ANDROID_SDK_ROOT` and `JAVA_HOME`.
  - Known NixOS issue: Gradle downloads a dynamically linked `aapt2` that won't run. Fix with `GRADLE_OPTS="-Dorg.gradle.project.android.aapt2FromMavenOverride=$ANDROID_HOME/build-tools/<ver>/aapt2"` in the shell hook (or document `programs.nix-ld.enable = true` as the alternative). Record the choice in an ADR.
  - If the Flutter Gradle plugin wants a different NDK version than the flake provides, read the version from the build error and add it to the flake rather than letting Gradle download one.
- [x] **P0.2 Toolchain check.** `flutter doctor -v` shows no Android errors. Create a throwaway `flutter create` app outside the repo, build a debug APK and run it on a device or the emulator. Delete it afterwards.
- [x] **P0.3 Repo scaffold.** `git init`, `.gitignore` (Flutter + secrets list from `CLAUDE.md`), root `pubspec.yaml` as a pub workspace, shared `analysis_options.yaml` (`flutter_lints` plus `prefer_const_constructors`, `avoid_print`, `always_declare_return_types`), `docs/progress.md`, `docs/decisions/000-record-architecture-decisions.md`.
- [x] **P0.4 CI.** GitHub Actions workflow running `flutter analyze` and `flutter test` on push. Use a standard Flutter action, not Nix, to keep CI simple.

### [OMAR] tasks

- [x] **P0.5 Decide account type.** → **Organisation** (ADR 003). Personal (shows legal name, needs 12 testers × 14 days) or organisation (needs D-U-N-S — already held — and verification, skips the tester rule, can show a studio name). Record the decision in an ADR.
- [ ] **P0.6** Create the Google Play Console developer account (US$25) and complete identity verification. Allow up to a few days.
- [ ] **P0.7** Create an AdMob account and link a Google payments profile (W-8BEN tax info, AUD bank account).
- [ ] **P0.8** Create a Firebase project for game 1 (Analytics + Crashlytics).
- [x] **P0.9** Have an Android phone available with USB debugging enabled. The emulator is fine for development, but ads, haptics and performance must be checked on a real device.

**Acceptance:** `nix develop` → `flutter doctor` clean; a debug APK runs on a device; repo pushed with CI green.

---

## Phase 1 — `game_core` shared package

Everything here is reused by every game. Each service sits behind an abstract interface with a fake implementation for tests.

- [x] **P1.1 Logger.** Thin wrapper (levels, tag). No output in release except errors, which go to Crashlytics.
- [x] **P1.2 Storage.** `KeyValueStore` interface over `shared_preferences`; typed helpers for int/bool/string/JSON; in-memory fake.
- [x] **P1.3 Settings.** Sound, music, haptics, colour-blind patterns; persisted; exposed as `ValueNotifier`s.
- [ ] **P1.4 Audio.** `flame_audio` wrapper: preload SFX, play by enum id, respects settings, ducks when the app pauses.
- [ ] **P1.5 Haptics.** Light/medium/success patterns via `HapticFeedback`; respects settings.
- [x] **P1.6 Consent.** UMP flow via `google_mobile_ads`'s `ConsentInformation`/`ConsentForm`: request info update on every launch, show form if required, expose `canRequestAds` and `privacyOptionsRequired`, and provide `showPrivacyOptionsForm()`. Debug builds support UMP debug geography (EEA) for testing.
- [x] **P1.7 Ads service.** `AdsService` interface with `AdMobAdsService` and `FakeAdsService`.
  - Initialise the Mobile Ads SDK only after consent says ads can be requested.
  - Interstitial: preload, `maybeShowInterstitial(trigger)` applies caps from a passed-in `AdPolicy` (min seconds between shows, min games before first show, min game duration), reloads after show, swallows no-fill.
  - Rewarded: preload, `showRewarded()` returns `Future<bool>` (true only on earned reward), `isRewardedReady` notifier so the UI can hide or disable the offer.
  - Ad unit IDs from `String.fromEnvironment`, falling back to Google's sample test IDs when absent or when `kReleaseMode` is false.
  - Register test device IDs from `env/*.json`.
  - Unit test the cap logic with a fake clock.
- [ ] **P1.8 Analytics.** `Analytics` interface with Firebase and no-op implementations. Event names as constants: `game_start`, `game_end` (score, duration, moves, cause), `level_clear`/`line_clear`, `ad_interstitial_shown`, `ad_rewarded_offered`, `ad_rewarded_completed`, `tutorial_complete`, `daily_start`, `daily_end`. No personal data in parameters.
- [ ] **P1.9 Crash reporting.** Crashlytics wired to `FlutterError.onError` and `PlatformDispatcher.instance.onError`; disabled in debug.
- [x] **P1.10 Review prompt.** `in_app_review` wrapper: ask at most once per N days, only after a positive moment (new best score, or Nth game won), never after a loss, never in the first session.
- [x] **P1.11 Theme.** Shared colour tokens (including a colour-blind-safe palette), typography using a bundled OFL font, button and dialog widgets with a consistent look.
- [x] **P1.12 House ads (stub).** Interface to show a cross-promo card for Omar's other games from a static list. Empty for game 1.

**Acceptance:** `game_core` tests pass with fakes; a small example screen in `game_core/example` shows consent → test interstitial → test rewarded on a real device.

---

## Phase 2 — Block puzzle: game design spec

Classic placement block puzzle. Original name and visuals — no borrowing from existing titles.

### P2.0 Naming [Claude Code proposes, OMAR picks]

- [ ] Propose 8 names. Each must contain a searchable term ("block puzzle", "blocks") in the store title, not match an existing game's name, and have a free `.com` or at least no obvious trademark clash. Omar picks one. Package id: `com.<omar's chosen prefix>.<name>`.

### Rules

- **Board:** 8×8 grid.
- **Tray:** 3 pieces offered at a time. The player drags any piece onto the board. When all 3 are placed, a new tray of 3 is generated.
- **No rotation.** Pieces are placed as shown.
- **Clearing:** after each placement, every full row and every full column clears at the same time. A cell in both a full row and a full column counts once.
- **Game over:** when no remaining tray piece fits anywhere on the board.
- **Piece set** (each orientation is a separate piece definition):
  - Mono (1), domino (2: H/V), I3 (2), I4 (2), I5 (2)
  - Small corner L3 (4 rotations), L4 (4) and J4 (4), T4 (4), S4/Z4 (2 each)
  - O 2×2, big square 3×3, big corner 3×3 L (4 rotations)

### Scoring (all values in `constants.dart`)

- +1 per cell placed.
- Line clear points by number of lines cleared in one placement: 1 → 10, 2 → 30, 3 → 60, 4 → 100, each extra line +50.
- **Streak:** a placement that clears at least one line increments the streak; 3 placements in a row without a clear reset it to 0. Line clear points × (1 + streak).
- **Board clear bonus:** +300 when the board is empty after a clear.

### Piece generation

- Weighted random from the piece set, using the injected seeded RNG.
- Weights shift with score bands (easy → normal → hard): fewer monos and dominos, more 3×3 and I5 as score rises. Bands and weights in `constants.dart`.
- **Fairness rule:** when generating a tray, at least one of the 3 pieces must fit the current board. Retry up to 20 times; if still none fit, replace one piece with the largest piece that does fit. If nothing at all fits, the game is over.
- The first tray of every game contains only pieces of size ≤ 3.

### Modes

- **Classic:** endless, best score saved.
- **Daily challenge:** seed derived from the local date (`yyyymmdd`), so every player gets the same sequence that day. Separate best score and a streak of days played. Local only, no server.

### Rewarded "second chance"

- Offered once per game at game over, only if a rewarded ad is ready.
- Reward: the tray is replaced with 3 pieces that are each guaranteed to fit the current board.
- If the player declines or the ad fails, go straight to results.

### Ad placement and caps (initial values in `constants.dart`)

- Interstitial: after the results screen when the player taps "Play again" or "Home".
  - Never in the first 2 games of a fresh install.
  - At least 120 s since the last interstitial.
  - Skip if the game lasted under 30 s.
  - Skip if a rewarded ad was watched in the same game-over flow.
- Banner: none at launch. (Revisit after launch on the home screen only, if retention data supports it.)
- No ads in the tutorial.

### Feel ("juice") — code-drawn

- Blocks: rounded squares with a subtle top highlight and darker bottom edge, drawn on `Canvas`; 7–8 colours from the theme palette; optional pattern overlay per colour for colour-blind mode.
- Drag: piece lifts and scales up ~1.15×, rendered above the finger (configurable offset ~1.5 cells) so the finger doesn't cover it. Ghost preview on the board shows where it will land; red tint or no ghost when it doesn't fit.
- Snap: piece snaps to the nearest valid cell within half a cell; otherwise returns to the tray with an ease-out animation.
- Clear: cleared cells flash, shrink and burst into particles; short screen shake on 3+ lines; floating score text; streak counter pulses.
- Sound: place, clear (pitch rises with streak), invalid drop, game over, new best. Kenney CC0 interface/UI sound packs.
- Haptics: light on place, medium on clear, success on new best.

### Screens

Home (Classic, Daily, Settings, best score) → Game → Game over (second-chance offer) → Results (score, best, "Play again", "Home") ; Settings (sound, haptics, colour-blind patterns, privacy options, privacy policy link, credits/licences, version).

### Tutorial

First launch only: 3 scripted steps on a preset board (drag a piece; complete a row; complete a column). Skippable. Fires `tutorial_complete`.

### Resume

Save the full game state (board, tray, score, streak, RNG state, mode) on every placement and on `AppLifecycleState.paused`. Offer "Continue" on Home if a saved game exists.

**Acceptance for Phase 2:** this spec is copied into `apps/block_puzzle/SPEC.md`; Omar has picked a name; any spec changes are logged in an ADR.

---

## Phase 3 — Block puzzle: model (pure Dart)

- [x] **P3.1** `Piece` (cells as offsets, id, colour index), full piece set as constants; test every piece's cell count and bounding box.
- [x] **P3.2** `Board` (8×8, immutable or copy-on-write): `canPlace`, `place`, `findFullLines`, `clearLines`, `anyFit(piece)`, `isEmpty`. Tests including corner cases (row + column overlap, placing on edges, full board).
- [x] **P3.3** `Scoring` per the spec. Table-driven tests for every rule.
- [x] **P3.4** `PieceGenerator` with seeded RNG, score bands and fairness rule. Tests: same seed → same trays; first tray sizes ≤ 3; fairness holds over 10,000 random boards; fallback path covered.
- [x] **P3.5** `GameState` + `GameController`: tray management, placement, clearing, scoring, game-over detection, second-chance tray, JSON (de)serialisation including RNG state. Tests: replay a recorded move list and assert final score; serialise mid-game and resume to an identical state.
- [x] **P3.6** Daily seed function. Test that the same date gives the same seed and adjacent dates differ.
- [x] **P3.7 Simulation tool.** `tool/simulate.dart`: plays N games with a simple greedy bot and prints average score, average game length (placements), and distribution of game-over causes. Used to tune weights so a casual player's median game lasts roughly 3–6 minutes. Record the tuning results in `docs/progress.md`.

**Acceptance:** model test coverage ≥ 90% (`flutter test --coverage`); simulation runs and its numbers are logged.

---

## Phase 4 — Block puzzle: rendering and input (Flame)

- [x] **P4.1** `FlameGame` subclass hosting board and tray components; scales to screen width with safe-area insets; works from small phones (360 dp wide) to tablets (letterboxed).
- [x] **P4.2** Block rendering per the feel spec, cached to `Picture`/`Image` per colour for performance.
- [x] **P4.3** Drag-and-drop with lift, finger offset, ghost preview, snap or return.
- [x] **P4.4** Clear animation, particles, floating score, screen shake, streak indicator.
- [x] **P4.5** Audio and haptics hooks through `game_core`.
- [x] **P4.6** Golden tests for board states (empty, mid-game, ghost valid, ghost invalid, colour-blind mode).
- [x] **P4.7 Performance.** Profile on the real device: steady 60 fps during clears; no jank on first clear (pre-warm particles and shaders).

**Acceptance:** a full Classic game is playable on a device start to game over; [OMAR] plays 5 games and gives feedback on feel, which Claude Code applies before moving on.

---

## Phase 5 — Block puzzle: app shell and meta

- [x] **P5.1** Screens and navigation per the spec, using `game_core` theme widgets; `PopScope` for back handling (back from Game asks to pause/quit; back from Home exits).
- [x] **P5.2** Flame overlays for pause, game over and second-chance offer.
- [x] **P5.3** Persistence: best scores (Classic, Daily), daily streak, games played, settings, saved game.
- [x] **P5.4** Daily challenge mode.
- [x] **P5.5** Tutorial.
- [x] **P5.6** Settings screen including "Privacy options" (shown only when UMP requires it), privacy policy link and credits screen listing CC0/OFL assets and licences.
- [x] **P5.7** Widget tests for each screen; integration test that plays a scripted Classic game end to end with `FakeAdsService`.

**Acceptance:** all flows work offline; airplane-mode launch doesn't hang on consent or ads.

---

## Phase 6 — Monetisation, analytics, crash reporting

- [ ] **P6.1** Wire `AdMobAdsService` with the block puzzle's `AdPolicy` from `constants.dart`.
- [ ] **P6.2** Second-chance rewarded flow; hide the offer when no rewarded ad is ready.
- [ ] **P6.3** Interstitial trigger on results → "Play again"/"Home" with caps.
- [ ] **P6.4** Analytics events per P1.8 at the right points. Verify in Firebase DebugView.
- [ ] **P6.5** Crashlytics: force a test crash in a debug-only menu, confirm it appears, then remove the trigger.
- [ ] **P6.6** Review prompt after a new best score per P1.10 rules.
- [ ] **P6.7** Unit tests for the "should show interstitial now?" decision across all cap rules.

### [OMAR] tasks

- [ ] **P6.8** In AdMob: create the app, one interstitial unit and one rewarded unit; create the GDPR consent message (and US state regulations message) in Privacy & messaging; put the app ID and unit IDs in `apps/block_puzzle/env/prod.json` (shape in `env/example.json`). Add your phone as a test device.
- [ ] **P6.9** Download `google-services.json` from Firebase into `apps/block_puzzle/android/app/` (gitignored).

**Acceptance:** on a real device with test IDs: consent form appears under EEA debug geography; interstitial respects every cap; rewarded grants the second chance only on completion; events show in DebugView; no ad ever appears during play.

---

## Phase 7 — Release engineering

- [ ] **P7.1** App id, display name, version scheme (`1.0.0+1`, build number incremented every upload).
- [ ] **P7.2** `minSdk` 24 (or Flutter's default if higher), `targetSdk` 36, `compileSdk` 36. Confirm 16 KB page-size compatibility with the APK Analyzer or `zipalign -c -P 16`.
- [ ] **P7.3** R8/minification on for release; keep rules for Flutter, Google Mobile Ads and Firebase if needed. Test the release build on device — ads and analytics must still work.
- [ ] **P7.4 Signing.** Gradle reads `android/key.properties` (gitignored). Document the `keytool` command in `docs/release.md`. Use Play App Signing; the local key is the upload key.
- [ ] **P7.5 Icon.** `tool/render_icon.dart` draws the icon in code (stacked blocks on a gradient) and writes 1024×1024 and 512×512 PNGs; adaptive icon foreground/background layers via `flutter_launcher_icons`. Check the foreground sits inside the 66% safe zone.
- [ ] **P7.6** Splash via `flutter_native_splash` matching the theme background (Android 12+ splash API).
- [ ] **P7.7** `flutter build appbundle --release --dart-define-from-file=env/prod.json` produces a signed AAB. Add a `make release` or `tool/release.sh` script that runs analyze, test, builds and prints the AAB path and version.
- [ ] **P7.8** `docs/release.md`: step-by-step for building, uploading, and bumping versions.

### [OMAR] tasks

- [ ] **P7.9** Generate the upload keystore yourself with the documented command; store it and its passwords in your password manager plus an offline backup. Losing it means a key reset request to Google.

**Acceptance:** signed release AAB built from a clean checkout with one command; release build tested on device (with test ad IDs via `env/test.json`) before the production build with real IDs is made.

---

## Phase 8 — Store listing, legal and assets

- [ ] **P8.1 Screenshots.** Integration test drives the game into 5–6 attractive states (mid-combo, big clear, daily challenge, new best) and captures screenshots on a 1080×1920 (or taller) emulator. `tool/frame_screenshots.dart` adds a coloured background and one short caption per screenshot. Output to `docs/store/block_puzzle/screenshots/`.
- [ ] **P8.2 Feature graphic.** 1024×500 PNG rendered in code by `tool/render_feature_graphic.dart`.
- [ ] **P8.3 Listing text.** Title (≤ 30 chars, includes "Block Puzzle"), short description (≤ 80), full description (≤ 4000) written for people, with the main search terms used naturally a few times, no keyword stuffing, no references to other games. Save as `docs/store/block_puzzle/listing-en.md`.
- [ ] **P8.4 Localised listings.** Translate title, short and full descriptions and screenshot captions into: es, pt-BR, fr, de, id, tr, ru, ja, ko, hi. Mark them for Omar to spot-check.
- [ ] **P8.5 Privacy policy.** `docs/legal/privacy-policy.md` covering AdMob (advertising ID, device and usage data, consent), Firebase Analytics and Crashlytics, no account or personal data collected by the game itself, contact email, and how to opt out. Produce an HTML version for hosting.
- [ ] **P8.6 Data safety draft.** `docs/store/block_puzzle/data-safety.md` with proposed answers to each Play Console Data safety question based on the SDKs actually included, with notes linking to each SDK's own data-disclosure page.
- [ ] **P8.7 app-ads.txt.** Generate the file content from the AdMob publisher ID in `env/prod.json`.
- [ ] **P8.8 Content rating notes.** Proposed answers for the IARC questionnaire (no violence, no user content, ads present, no gambling).

### [OMAR] tasks

- [ ] **P8.9** Host the privacy policy and `app-ads.txt` at the root of your developer website (for example omarfahd.com/app-ads.txt) and confirm both URLs load.
- [ ] **P8.10** Review all listing text, translations spot-check, Data safety answers, and content rating answers before submitting. These are legal declarations made by you.

---

## Phase 9 — Testing tracks and launch

### [OMAR] tasks (Claude Code prepares checklists in `docs/launch-checklist.md`)

- [ ] **P9.1** Create the app in Play Console. Set target audience to 13+ (or 18+), fill App content (privacy policy, ads declaration "contains ads", Data safety, content rating, target audience, news/government: no).
- [ ] **P9.2** Upload the AAB to Internal testing; install from Play on your phone; play through once with real ads (don't tap them).
- [ ] **P9.3** *(Optional: organisation account, ADR 003.)* If on a personal account: promote to Closed testing and recruit **at least 15** testers (buffer over 12) — RMIT friends, ISR members, flying-school contacts, r/AndroidClosedTesting. Testers must stay opted in for 14 continuous days. Track them in a simple sheet.
- [ ] **P9.4** During the test: ship at least one update based on tester feedback (Google asks about testing in the production application).
- [ ] **P9.5** Apply for production access, answer the questionnaire, then release to production with a staged rollout (20% → 50% → 100% over a few days while watching crashes and ANRs).

### Claude Code tasks during testing

- [ ] **P9.6** Triage tester feedback and Crashlytics issues into `docs/progress.md`; fix, bump version, rebuild.
- [ ] **P9.7** Check Play Console pre-launch report findings and fix anything flagged (accessibility, crashes, security warnings).

**Acceptance:** game live in production; crash-free users ≥ 99.5%; ANR rate under Play's bad-behaviour threshold.

---

## Phase 10 — Post-launch loop (block puzzle)

Run weekly for the first 6–8 weeks.

- [ ] **P10.1** [OMAR] Export from Play Console and AdMob (or paste numbers): installs, D1/D7 retention, average session length, eCPM, impressions per DAU, ratings. Claude Code saves them in `docs/metrics/block_puzzle.md` and summarises trends.
- [ ] **P10.2** Rule-of-thumb triggers for what to work on:
  - D1 under ~25%: first-session problem — revisit tutorial, first-tray difficulty, ad caps for new installs.
  - D1 fine but D7 under ~8%: not enough long-term pull — add daily streak rewards, themes unlocked by playing, more modes.
  - Low impressions per DAU with good retention: carefully loosen interstitial caps one step at a time, measuring retention after each change.
  - Rating under 4.0: read reviews, fix the top complaint first.
- [ ] **P10.3** Store listing experiments in Play Console (icon first, then first screenshot).
- [ ] **P10.4** Short-form video: `tool/record_gameplay.md` documents capturing 15–30 s 9:16 clips with `adb shell screenrecord` on satisfying clears for TikTok, YouTube Shorts and Reels.
- [ ] **P10.5** Decide after ~500 installs: kill (leave live, stop work), iterate, or scale (more content, localisation, small paid test). Record the decision in an ADR.

---

## Game 2 — Idle / incremental (outline)

Start once game 1 is in production. Write a full `SPEC.md` (same depth as Phase 2) before coding.

- Reuses `game_core` unchanged; any new shared need goes into `game_core` first.
- Core loop: tap/automate generators → currency → upgrades → prestige reset with permanent multiplier.
- Offline earnings calculated from saved timestamp on resume (cap at e.g. 8 h; rewarded ad doubles it).
- Rewarded ads are the main revenue: "2× earnings for 10 min", "double offline earnings". Interstitials rarely or never.
- Big-number formatting (K, M, B... then scientific) and a pure-Dart economy model with a simulation tool to tune the curve so the first prestige lands around 20–40 minutes in.
- Same release, store and launch phases as game 1, much faster the second time.

## Game 3 — Aviation-themed puzzle (outline)

- Concept candidates to decide on: runway/landing timing puzzle, or an ATC-style routing puzzle (guide aircraft to runways without conflicts).
- Hand-authored or generated levels as JSON in `assets/levels/`, with a level validator tool and tests that every level is solvable.
- Marketing angle: flying schools, sim communities, cadets. Plan these posts before launch.
- House ads in all three games cross-promote each other from day one of game 3.

---

## Session start prompt for Omar to paste

> Read CLAUDE.md, PLAN.md and docs/progress.md. Tell me which phase and task we're on, what you'll do this session, and anything you need from me first. Then start.
