// End-to-end: real app, real storage/audio/haptics/rendering on a device;
// only ads and consent are fakes (no network). Plays a whole scripted
// Classic game through the normal drag path and checks Results and saved
// progress.
//
// Run: flutter test integration_test -d <device>
import 'package:block_puzzle/src/app/ad_config.dart';
import 'package:block_puzzle/src/app/app.dart';
import 'package:block_puzzle/src/app/services.dart';
import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/data/progress_store.dart';
import 'package:block_puzzle/src/game/block_game.dart';
import 'package:block_puzzle/src/game/sfx.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:block_puzzle/src/ui/game_screen.dart';
import 'package:block_puzzle/src/ui/home_screen.dart';
import 'package:block_puzzle/src/ui/results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Greedy choice: most lines cleared, then fewest filled cells after.
({int slot, int row, int col})? chooseMove(BlockGame g) {
  final s = g.controller.state;
  ({int slot, int row, int col})? best;
  var bestScore = -1 << 30;
  for (var slot = 0; slot < s.tray.length; slot++) {
    final p = s.tray[slot];
    if (p == null) continue;
    for (final pos in s.board.validPositions(p)) {
      final placed = s.board.place(p, pos.row, pos.col);
      final lines = placed.findFullLines();
      final after = placed.clearLines(lines);
      final score =
          (lines.rows.length + lines.cols.length) * 100 - after.filledCount;
      if (score > bestScore) {
        bestScore = score;
        best = (slot: slot, row: pos.row, col: pos.col);
      }
    }
  }
  return best;
}

Future<void> pumpFor(WidgetTester t, Duration d) async {
  final end = DateTime.now().add(d);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('plays a full Classic game end to end', (t) async {
    SharedPreferences.setMockInitialValues({}); // fresh install
    final store = await SharedPrefsStore.open();
    final settings = Settings(store)..sound.value = false;
    final analytics = RecordingAnalytics();
    final services = AppServices(
      store: store,
      progress: ProgressStore(store),
      settings: settings,
      audio: FlameAudioService<Sfx>(
        files: kSfxFiles,
        sound: settings.sound,
        music: settings.music,
      ),
      haptics: PlatformHaptics(settings.haptics),
      consent: FakeConsentService(),
      ads: FakeAdsService(policy: kAdPolicy, rewardedReady: false),
      analytics: analytics,
      version: 'test',
      newSeed: () => 20261111,
    );

    await t.pumpWidget(BlockPuzzleApp(services: services));
    await pumpFor(t, const Duration(seconds: 1));

    // First launch: tutorial. Skip it.
    await t.tap(find.byKey(const Key('skipTutorial')));
    await pumpFor(t, const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);

    await t.tap(find.byKey(const Key('play')));
    await pumpFor(t, const Duration(seconds: 1));
    final screen = t.state<GameScreenState>(find.byType(GameScreen));
    final game = screen.game;

    var moves = 0;
    while (!game.controller.isOver && moves < 500) {
      final m = chooseMove(game)!;
      final piece = game.controller.state.tray[m.slot]!;
      final home = game.slots[m.slot].home;
      expect(game.startDrag(m.slot, Offset(home.x, home.y)), isTrue);
      final tl = game.layout.cellRect(m.row, m.col).topLeft;
      game.moveDrag(
        Offset(
          tl.dx + piece.width * game.dragCell / 2,
          tl.dy +
              kDragFingerOffsetCells * game.layout.cell +
              piece.height * game.dragCell,
        ),
      );
      final r = game.endDrag();
      expect(r, isNotNull, reason: 'move $moves should land');
      moves++;
      await pumpFor(t, const Duration(milliseconds: 60));
    }
    expect(game.controller.isOver, isTrue, reason: 'game should end');
    final finalScore = game.controller.state.score;

    // Game over -> "No moves left" -> Results.
    await pumpFor(t, const Duration(seconds: 3));
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('$finalScore'), findsWidgets);

    final progress = ProgressStore(await SharedPrefsStore.open());
    expect(progress.bestFor(GameMode.classic), finalScore);
    expect(progress.gamesPlayed, 1);
    expect(progress.hasSavedGame(GameMode.classic), isFalse);
    expect(
      analytics.names,
      containsAllInOrder([
        AnalyticsEvents.tutorialComplete,
        AnalyticsEvents.gameStart,
        AnalyticsEvents.gameEnd,
      ]),
    );

    await t.tap(find.text('Home'));
    await pumpFor(t, const Duration(seconds: 1));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Best $finalScore'), findsOneWidget);

    // ignore: avoid_print
    print('integration: $moves moves, score $finalScore');
  });
}
