import 'package:block_puzzle/src/app/ad_config.dart';
import 'package:block_puzzle/src/app/services.dart';
import 'package:block_puzzle/src/data/progress_store.dart';
import 'package:block_puzzle/src/game/sfx.dart';
import 'package:block_puzzle/src/model/board.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/pieces.dart';
import 'package:block_puzzle/src/model/rng.dart';
import 'package:block_puzzle/src/model/scoring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meta/meta.dart';
import 'package:game_core/game_core.dart';

/// All-fake services for widget tests.
class TestServices {
  TestServices({
    DateTime? now,
    bool rewardedReady = false,
    bool rewardEarned = true,
    bool privacyOptionsRequired = false,
    this.privacyPolicyUrl = '',
    bool tutorialDone = true,
  }) : now = now ?? DateTime(2026, 11, 11, 12) {
    consent = FakeConsentService(
      privacyOptionsRequired: privacyOptionsRequired,
    );
    ads = FakeAdsService(
      policy: kAdPolicy,
      rewardedReady: rewardedReady,
      rewardEarned: rewardEarned,
      clock: () => this.now,
    );
    if (tutorialDone) store.values['tutorial.done'] = true;
    services = AppServices(
      store: store,
      progress: ProgressStore(store, clock: () => this.now),
      settings: Settings(store),
      audio: audio,
      haptics: haptics,
      consent: consent,
      ads: ads,
      analytics: analytics,
      clock: () => this.now,
      privacyPolicyUrl: privacyPolicyUrl,
      version: '0.1.0 (1)',
      openUrl: (u) async {
        opened.add(u);
        return true;
      },
      newSeed: () => 42,
    );
  }

  DateTime now;
  final String privacyPolicyUrl;
  final store = InMemoryStore();
  final audio = FakeAudioService<Sfx>();
  final haptics = FakeHaptics();
  final analytics = RecordingAnalytics();
  final opened = <Uri>[];
  late final FakeConsentService consent;
  late final FakeAdsService ads;
  late final AppServices services;

  ProgressStore get progress => services.progress;
}

/// Wraps [child] like the real app does.
Widget wrap(AppServices s, Widget child) => ServicesScope(
  services: s,
  child: MaterialApp(theme: buildGameTheme(), home: child),
);

/// Lets Flame load and run a few frames.
Future<void> settle(WidgetTester tester, [int frames = 25]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A state where placing the mono in slot 0 at (0,1) ends the game: a
/// checkerboard with no 3x3 gap, and an SQ3 left in the tray.
GameController nearlyOver({GameMode mode = GameMode.classic, int seed = 1}) =>
    GameController.fromState(
      GameState(
        mode: mode,
        seed: seed,
        board: Board.fromRows(const [
          '0.0.0.0.',
          '.0.0.0.0',
          '0.0.0.0.',
          '.0.0.0.0',
          '0.0.0.0.',
          '.0.0.0.0',
          '0.0.0.0.',
          '.0.0.0.0',
        ]),
        tray: [pieceById('mono'), pieceById('SQ3'), null],
        score: 120,
        streak: kInitialStreak,
        rngState: SeededRng(seed).state,
        placements: 30,
      ),
    );

/// testWidgets on a phone-sized screen (360x800 logical, 3x density).
@isTest
void phoneTest(String name, Future<void> Function(WidgetTester t) body) =>
    testWidgets(name, (t) async {
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await body(t);
    });
