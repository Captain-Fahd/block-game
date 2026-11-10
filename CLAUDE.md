# CLAUDE.md

Ad-supported Android games built with Flutter + Flame, published by Omar (organisation Play developer account). `PLAN.md` holds the phased plan; this file holds the rules for working in the repo.

## Start of every session
1. Read `CLAUDE.md`, `PLAN.md` and `docs/progress.md`.
2. Say which phase and task is next, what you'll do this session, and anything you need from Omar first.
3. Work through the plan in order unless Omar says otherwise. Tasks marked **[OMAR]** are his; prepare what he needs, but don't pretend to do them.

## Working with the plan
- Tick a box in `PLAN.md` (`- [x]`) only when the task's acceptance criteria are met and verified (tests pass, it ran on the emulator/device, and so on). If something was only partly done, say so in `docs/progress.md`.
- Add an entry to `docs/progress.md` every session (newest first): what got done, measured numbers, what's next, and blockers.
- Record significant decisions and every spec change as an ADR in `docs/decisions/NNN-short-title.md` (Context / Decision / Consequences).
- If a platform fact in `PLAN.md` turns out to be different (API levels, plugin versions, Play policy), update the plan and tell Omar.
- Ask Omar when a decision changes the product, costs money, or is a legal declaration. Otherwise pick a sensible default, record it, and keep going.

## Environment
- Everything runs inside the Nix dev shell: `nix develop` (or `nix develop -c <cmd>`). Don't install toolchains globally or let Gradle download SDK components; add them to `flake.nix` instead.
- Emulator: AVD `bp_api36` (API 36, Play Store image). Ads, haptics and performance must also be checked on Omar's real phone.
- The `flutter` version in CI (`.github/workflows/ci.yml`) must match the nixpkgs Flutter in `flake.lock`. Bump them together.

## Repo layout
- `packages/game_core/` holds shared services used by every game (ads, consent, analytics, storage, audio, haptics, review, theme, logger). Any new shared need goes here first, never copy-pasted between apps.
- `apps/<game>/` holds one Flutter app per game:
  - `lib/src/model/` is pure Dart game logic, with no Flutter or Flame imports.
  - `lib/src/game/` holds the Flame components.
  - `lib/src/ui/` holds the Flutter screens and overlays.
  - `lib/src/constants.dart` holds every tunable number.
  - `SPEC.md` is the game's rules and the source of truth.
- `docs/` holds progress, decisions, store listings and legal text.
- The root `pubspec.yaml` is a pub workspace. Each member uses `resolution: workspace`.

## Code rules
- Run `dart format` on every change; `flutter analyze` must show no issues; `flutter test` must pass before committing.
- Game logic stays pure and deterministic. Randomness comes only from the injected `SeededRng` (serialisable), never `dart:math` `Random` or `DateTime.now()` inside the model.
- Every service in `game_core` sits behind an abstract interface with a fake implementation for tests. Apps depend on the interface.
- All gameplay and monetisation numbers (scores, weights, ad caps) live in `constants.dart`, not inline.
- Use `print` only in `tool/` scripts. App code uses the `game_core` logger.
- Model code keeps ≥ 90% line coverage (`flutter test --coverage`).
- Original names and visuals only. Never copy or reference another game's name, art, sounds or levels. Assets are code-drawn, or CC0/OFL with credits listed in the app.

## Ads and privacy
- Ads are never shown during gameplay or in the tutorial. Follow the caps in `constants.dart` and the spec.
- Debug and profile builds always use Google's sample test ad unit IDs. Real IDs only come in via `--dart-define-from-file=env/prod.json` in release builds.
- Initialise the Mobile Ads SDK only after UMP consent says ads can be requested.
- Analytics events carry no personal data.

## Secrets: never commit these
- `apps/*/env/*.json` (except `env/example.json`), which hold AdMob app/unit IDs and test device IDs
- `**/android/key.properties`, `*.jks`, `*.keystore` (upload keystore and passwords)
- `google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`
- `.env*` files, and any API keys or tokens

These are in `.gitignore`. Before each commit, check `git status` for anything that looks like a secret. If one was committed, stop and tell Omar; don't just delete it in a new commit.

## Git
- Commit and push to `main` freely once format, analyze and tests pass. Use small, focused commits with messages that say what changed and why.
- CI (`analyze` + `test`) must stay green. If a push breaks it, fix it next.
- Never force-push, and never rewrite published history.

## Identity
- Play developer account: **organisation** (ADR 003).
- Package prefix: `com.omarfahd`. App id `com.omarfahd.<name>` once the game's name is picked (P2.0).
- Developer website (for the privacy policy and `app-ads.txt`): Omar's domain, to be confirmed.
