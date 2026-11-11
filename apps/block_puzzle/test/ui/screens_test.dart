import 'package:block_puzzle/src/app/app.dart';
import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/block_game.dart';
import 'package:block_puzzle/src/model/daily_seed.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/model/piece.dart';
import 'package:block_puzzle/src/ui/game_screen.dart';
import 'package:block_puzzle/src/ui/home_screen.dart';
import 'package:block_puzzle/src/ui/results_screen.dart';
import 'package:block_puzzle/src/ui/settings_screen.dart';
import 'package:block_puzzle/src/ui/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'helpers.dart';

/// Places tray [slot]'s piece with its top-left on ([row], [col]).
PlacementResult? place(BlockGame g, int slot, int row, int col) {
  final Piece piece = g.controller.state.tray[slot]!;
  final home = g.slots[slot].home;
  g.startDrag(slot, Offset(home.x, home.y));
  final tl = g.layout.cellRect(row, col).topLeft;
  g.moveDrag(
    Offset(
      tl.dx + piece.width * g.dragCell / 2,
      tl.dy +
          kDragFingerOffsetCells * g.layout.cell +
          piece.height * g.dragCell,
    ),
  );
  return g.endDrag();
}

GameScreenState gameState(WidgetTester t) =>
    t.state<GameScreenState>(find.byType(GameScreen));

void main() {
  group('App', () {
    phoneTest('first launch shows the tutorial, later launches Home', (
      t,
    ) async {
      final ts = TestServices(tutorialDone: false);
      await t.pumpWidget(BlockPuzzleApp(services: ts.services));
      await settle(t);
      expect(find.byType(TutorialScreen), findsOneWidget);

      final ts2 = TestServices();
      await t.pumpWidget(BlockPuzzleApp(services: ts2.services));
      await settle(t);
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Home', () {
    phoneTest('fresh: Play and Daily, no Continue', (t) async {
      final ts = TestServices();
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      expect(find.byKey(const Key('play')), findsOneWidget);
      expect(find.byKey(const Key('continue')), findsNothing);
      expect(find.text('Daily challenge'), findsOneWidget);
    });

    phoneTest('saved games show Continue (with score) and Continue daily', (
      t,
    ) async {
      final ts = TestServices();
      await ts.progress.saveGame(
        GameController.newGame(
          mode: GameMode.classic,
          seed: 3,
        ).state.copyWith(score: 77),
      );
      await ts.progress.saveGame(
        GameController.newGame(
          mode: GameMode.daily,
          seed: dailySeed(ts.now),
        ).state,
      );
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      expect(find.textContaining('Continue  ·  77'), findsOneWidget);
      expect(find.byKey(const Key('newGame')), findsOneWidget);
      expect(find.text('Continue daily'), findsOneWidget);
    });

    phoneTest('shows best, today\'s daily best and streak', (t) async {
      final ts = TestServices();
      await ts.progress.recordGameEnd(
        GameController.newGame(
          mode: GameMode.classic,
          seed: 1,
        ).state.copyWith(score: 500, isOver: true),
      );
      await ts.progress.recordGameEnd(
        GameController.newGame(
          mode: GameMode.daily,
          seed: dailySeed(ts.now),
        ).state.copyWith(score: 90, isOver: true),
      );
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      expect(find.text('Best 500'), findsOneWidget);
      expect(find.textContaining("Today's best 90"), findsOneWidget);
      expect(find.textContaining('Streak 1 day'), findsOneWidget);
    });

    phoneTest('Play opens a classic game; Daily opens today\'s daily', (
      t,
    ) async {
      final ts = TestServices();
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      await t.tap(find.byKey(const Key('play')));
      await settle(t);
      expect(gameState(t).mode, GameMode.classic);
      expect(ts.analytics.names, contains(AnalyticsEvents.gameStart));

      gameState(t).quitToHome();
      await settle(t);
      await t.tap(find.byKey(const Key('daily')));
      await settle(t);
      expect(gameState(t).mode, GameMode.daily);
      expect(gameState(t).game.controller.state.seed, dailySeed(ts.now));
      expect(ts.analytics.names, contains(AnalyticsEvents.dailyStart));
    });

    phoneTest('Settings button opens Settings', (t) async {
      final ts = TestServices();
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      await t.tap(find.byKey(const Key('settings')));
      await settle(t);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('Game', () {
    Future<GameScreenState> open(
      WidgetTester t,
      TestServices ts,
      GameController c,
    ) async {
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      final nav = t.state<NavigatorState>(find.byType(Navigator));
      nav.push(
        MaterialPageRoute<void>(builder: (_) => GameScreen(controller: c)),
      );
      await settle(t);
      return gameState(t);
    }

    phoneTest('a placement saves the game', (t) async {
      final ts = TestServices();
      final s = await open(
        t,
        ts,
        GameController.newGame(mode: GameMode.classic, seed: 5),
      );
      expect(place(s.game, 0, 0, 0), isNotNull);
      await t.pump();
      expect(ts.progress.loadGame(GameMode.classic)?.placements, 1);
    });

    phoneTest('pause button and back button pause; Resume resumes', (t) async {
      final ts = TestServices();
      final s = await open(
        t,
        ts,
        GameController.newGame(mode: GameMode.classic, seed: 5),
      );
      await t.tap(find.byKey(const Key('pause')));
      await settle(t, 3);
      expect(find.text('Paused'), findsOneWidget);
      expect(s.game.paused, isTrue);
      expect(
        s.game.startDrag(0, Offset.zero),
        isFalse,
        reason: 'no drags while paused',
      );

      await t.tap(find.text('Resume'));
      await settle(t, 3);
      expect(find.text('Paused'), findsNothing);
      expect(s.game.paused, isFalse);

      await t.binding.handlePopRoute(); // Android back
      await settle(t, 3);
      expect(find.text('Paused'), findsOneWidget);
      await t.binding.handlePopRoute(); // back again resumes
      await settle(t, 3);
      expect(find.text('Paused'), findsNothing);
      expect(
        find.byType(GameScreen),
        findsOneWidget,
        reason: 'back never leaves mid-game',
      );
    });

    phoneTest('pause > Home saves and returns Home with Continue', (t) async {
      final ts = TestServices();
      // Through Home's own Play button, so Home refreshes on return.
      await t.pumpWidget(wrap(ts.services, const HomeScreen()));
      await t.tap(find.byKey(const Key('play')));
      await settle(t);
      final s = gameState(t);
      place(s.game, 0, 0, 0);
      s.pause();
      await settle(t, 3);
      await t.tap(find.text('Home'));
      await settle(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('continue')), findsOneWidget);
    });

    phoneTest('pause > Restart starts a fresh game', (t) async {
      final ts = TestServices();
      final s = await open(
        t,
        ts,
        GameController.newGame(mode: GameMode.classic, seed: 5),
      );
      place(s.game, 0, 0, 0);
      s.pause();
      await settle(t, 3);
      await t.tap(find.text('Restart'));
      await settle(t, 3);
      expect(s.game.controller.state.placements, 0);
      expect(s.game.controller.state.board.isEmpty, isTrue);
      expect(s.game.paused, isFalse);
    });

    phoneTest(
      'game over without a rewarded ad goes to Results and records it',
      (t) async {
        final ts = TestServices();
        final s = await open(t, ts, nearlyOver());
        expect(place(s.game, 0, 0, 1)!.gameOver, isTrue);
        await settle(t, 20); // game-over delay
        expect(find.text('No moves left'), findsOneWidget);
        expect(find.text('Second chance'), findsNothing);
        await settle(t, 30);
        expect(find.byType(ResultsScreen), findsOneWidget);
        expect(find.text('121'), findsOneWidget);
        expect(find.text('New best!'), findsOneWidget);
        expect(ts.progress.bestFor(GameMode.classic), 121);
        expect(ts.progress.gamesPlayed, 1);
        expect(ts.progress.hasSavedGame(GameMode.classic), isFalse);
        final end = ts.analytics.events.lastWhere(
          (e) => e.$1 == AnalyticsEvents.gameEnd,
        );
        expect(end.$2['score'], 121);
        expect(end.$2['cause'], 'SQ3');
        expect(
          ts.analytics.names,
          isNot(contains(AnalyticsEvents.adRewardedOffered)),
        );
      },
    );

    phoneTest(
      'second chance: offered when ready; watching continues the game',
      (t) async {
        final ts = TestServices(rewardedReady: true);
        final s = await open(t, ts, nearlyOver());
        place(s.game, 0, 0, 1);
        await settle(t, 20);
        expect(find.text('Second chance'), findsOneWidget);
        expect(ts.analytics.names, contains(AnalyticsEvents.adRewardedOffered));

        await t.tap(find.text('Second chance'));
        await settle(t, 10);
        expect(ts.ads.rewardedShown, 1);
        expect(find.text('No moves left'), findsNothing);
        expect(s.game.controller.isOver, isFalse);
        expect(s.game.controller.canUseSecondChance, isFalse);
        expect(
          ts.analytics.names,
          contains(AnalyticsEvents.adRewardedCompleted),
        );
        for (final p in s.game.controller.state.tray) {
          expect(s.game.controller.state.board.anyFit(p!), isTrue);
        }
      },
    );

    phoneTest('second chance: declining goes to Results', (t) async {
      final ts = TestServices(rewardedReady: true);
      final s = await open(t, ts, nearlyOver());
      place(s.game, 0, 0, 1);
      await settle(t, 20);
      await t.tap(find.text('No thanks'));
      await settle(t, 10);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(ts.ads.rewardedShown, 0);
    });

    phoneTest('second chance: ad not completed goes to Results', (t) async {
      final ts = TestServices(rewardedReady: true, rewardEarned: false);
      final s = await open(t, ts, nearlyOver());
      place(s.game, 0, 0, 1);
      await settle(t, 20);
      await t.tap(find.text('Second chance'));
      await settle(t, 10);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(
        ts.analytics.names,
        isNot(contains(AnalyticsEvents.adRewardedCompleted)),
      );
    });
  });

  group('Results', () {
    phoneTest(
      'daily results show the streak; Play again starts a game; Home pops',
      (t) async {
        final ts = TestServices();
        await t.pumpWidget(wrap(ts.services, const HomeScreen()));
        final nav = t.state<NavigatorState>(find.byType(Navigator));
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => const ResultsScreen(
              mode: GameMode.daily,
              record: (
                score: 40,
                previousBest: 60,
                best: 60,
                newBest: false,
                gamesPlayed: 3,
                dailyStreak: 4,
              ),
              gameDuration: Duration(minutes: 2),
              rewardedWatched: false,
            ),
          ),
        );
        await settle(t);
        expect(find.text('40'), findsOneWidget);
        expect(find.text('Best 60'), findsOneWidget);
        expect(find.text('New best!'), findsNothing);
        expect(find.text('Daily streak: 4 days'), findsOneWidget);

        await t.tap(find.text('Play again'));
        await settle(t);
        expect(gameState(t).mode, GameMode.daily);

        gameState(t).quitToHome();
        await settle(t);
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );
  });

  group('Settings', () {
    phoneTest('toggles change and persist settings', (t) async {
      final ts = TestServices();
      await t.pumpWidget(wrap(ts.services, const SettingsScreen()));
      await t.tap(find.byKey(const Key('toggle:Vibration')));
      await t.tap(find.byKey(const Key('toggle:Colour-blind patterns')));
      await t.pump();
      expect(ts.services.settings.haptics.value, isFalse);
      expect(ts.services.settings.colourBlindPatterns.value, isTrue);
      expect(Settings(ts.store).haptics.value, isFalse, reason: 'persisted');
      expect(find.text('0.1.0 (1)'), findsOneWidget);
    });

    phoneTest('privacy options only when consent requires them', (t) async {
      final off = TestServices();
      await t.pumpWidget(wrap(off.services, const SettingsScreen()));
      expect(find.byKey(const Key('privacyOptions')), findsNothing);

      final on = TestServices(privacyOptionsRequired: true);
      await t.pumpWidget(wrap(on.services, const SettingsScreen()));
      await t.tap(find.byKey(const Key('privacyOptions')));
      await t.pump();
      expect(on.consent.privacyFormShows, 1);
    });

    phoneTest('privacy policy link only when a URL is configured', (t) async {
      final none = TestServices();
      await t.pumpWidget(wrap(none.services, const SettingsScreen()));
      expect(find.byKey(const Key('privacyPolicy')), findsNothing);

      final ts = TestServices(privacyPolicyUrl: 'https://example.org/privacy');
      await t.pumpWidget(wrap(ts.services, const SettingsScreen()));
      await t.tap(find.byKey(const Key('privacyPolicy')));
      await t.pump();
      expect(ts.opened.single.toString(), 'https://example.org/privacy');
    });

    phoneTest('credits open the licence page', (t) async {
      final ts = TestServices();
      await t.pumpWidget(wrap(ts.services, const SettingsScreen()));
      await t.tap(find.byKey(const Key('credits')));
      await settle(t);
      expect(find.byType(LicensePage), findsOneWidget);
    });
  });

  group('Tutorial', () {
    Future<TutorialScreenState> open(
      WidgetTester t,
      TestServices ts,
      VoidCallback onDone,
    ) async {
      await t.pumpWidget(wrap(ts.services, TutorialScreen(onDone: onDone)));
      await settle(t);
      return t.state<TutorialScreenState>(find.byType(TutorialScreen));
    }

    phoneTest('three steps, a miss resets, finishing marks it done', (t) async {
      final ts = TestServices(tutorialDone: false);
      var done = 0;
      final s = await open(t, ts, () => done++);
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(s.game.hiddenSlots, {1, 2});
      expect(s.game.startDrag(1, Offset.zero), isFalse, reason: 'hidden slot');

      place(s.game, 0, 3, 3);
      await settle(t, 20);
      expect(s.step, 1);
      expect(s.game.hintCells, hasLength(3));

      place(s.game, 0, 0, 0); // somewhere that doesn't clear
      await settle(t, 20);
      expect(s.step, 1);
      expect(find.text('Almost! Fill the highlighted cells.'), findsOneWidget);
      expect(
        s.game.controller.state.board.isFilled(0, 0),
        isFalse,
        reason: 'reset',
      );

      place(s.game, 0, 7, 0);
      await settle(t, 20);
      expect(s.step, 2);
      place(s.game, 0, 5, 7);
      await settle(t, 20);
      expect(s.finished, isTrue);

      await t.tap(find.byKey(const Key('tutorialPlay')));
      await t.pump();
      expect(done, 1);
      expect(ts.progress.tutorialDone, isTrue);
      final e = ts.analytics.events.single;
      expect(e.$1, AnalyticsEvents.tutorialComplete);
      expect(e.$2['skipped'], 0);
    });

    phoneTest('skip marks it done', (t) async {
      final ts = TestServices(tutorialDone: false);
      var done = 0;
      await open(t, ts, () => done++);
      await t.tap(find.byKey(const Key('skipTutorial')));
      await t.pump();
      expect(done, 1);
      expect(ts.progress.tutorialDone, isTrue);
      expect(ts.analytics.events.single.$2['skipped'], 1);
    });
  });
}
