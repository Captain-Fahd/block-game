import 'package:block_puzzle/src/data/progress_store.dart';
import 'package:block_puzzle/src/model/daily_seed.dart';
import 'package:block_puzzle/src/model/game_controller.dart';
import 'package:block_puzzle/src/model/game_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  late InMemoryStore kv;
  late DateTime now;
  late ProgressStore p;

  setUp(() {
    kv = InMemoryStore();
    now = DateTime(2026, 11, 11, 20);
    p = ProgressStore(kv, clock: () => now);
  });

  GameState game(GameMode mode, int score, {int? seed, bool over = true}) =>
      GameController.newGame(
        mode: mode,
        seed: seed ?? (mode == GameMode.daily ? dailySeed(now) : 7),
      ).state.copyWith(score: score, isOver: over);

  group('scores', () {
    test('fresh install: zeros, tutorial not done, no saves', () {
      expect(p.bestFor(GameMode.classic), 0);
      expect(p.bestFor(GameMode.daily), 0);
      expect(p.gamesPlayed, 0);
      expect(p.dailyStreak, 0);
      expect(p.tutorialDone, isFalse);
      expect(p.hasSavedGame(GameMode.classic), isFalse);
    });

    test(
      'best updates only when beaten; games played counts every end',
      () async {
        var r = await p.recordGameEnd(game(GameMode.classic, 100));
        expect(r.newBest, isTrue);
        expect(r.previousBest, 0);
        r = await p.recordGameEnd(game(GameMode.classic, 80));
        expect(r.newBest, isFalse);
        expect(r.best, 100);
        r = await p.recordGameEnd(game(GameMode.classic, 150));
        expect((r.newBest, r.previousBest, r.best), (true, 100, 150));
        expect(p.gamesPlayed, 3);
        expect(p.bestFor(GameMode.daily), 0, reason: 'modes are separate');
      },
    );

    test('daily: today best, all-time best, and streak', () async {
      await p.recordGameEnd(game(GameMode.daily, 40));
      await p.recordGameEnd(game(GameMode.daily, 30));
      expect(p.todayDailyBest, 40);
      expect(p.bestFor(GameMode.daily), 40);
      expect(p.dailyStreak, 1);
      expect(p.bestFor(GameMode.classic), 0);
    });
  });

  group('daily streak', () {
    Future<void> playDailyOn(DateTime day) async {
      now = day;
      await p.recordGameEnd(game(GameMode.daily, 10));
    }

    test('consecutive days count up; same day does not double count', () async {
      await playDailyOn(DateTime(2026, 11, 9, 9));
      await playDailyOn(DateTime(2026, 11, 9, 22));
      await playDailyOn(DateTime(2026, 11, 10, 8));
      await playDailyOn(DateTime(2026, 11, 11, 23));
      expect(p.dailyStreak, 3);
    });

    test('still shown the next day; lost after a missed day', () async {
      await playDailyOn(DateTime(2026, 11, 10));
      now = DateTime(2026, 11, 11, 12);
      expect(p.dailyStreak, 1);
      now = DateTime(2026, 11, 12, 12);
      expect(p.dailyStreak, 0);
      await playDailyOn(DateTime(2026, 11, 12, 13));
      expect(p.dailyStreak, 1, reason: 'restarts at 1');
    });

    test('across a month boundary', () async {
      await playDailyOn(DateTime(2026, 11, 30));
      await playDailyOn(DateTime(2026, 12, 1));
      expect(p.dailyStreak, 2);
    });

    test('a daily that ends after midnight counts for its own date', () async {
      final yesterday = DateTime(2026, 11, 10, 23, 50);
      now = DateTime(2026, 11, 11, 0, 10);
      await p.recordGameEnd(
        game(GameMode.daily, 55, seed: dailySeed(yesterday)),
      );
      expect(p.todayDailyBest, 0);
      expect(kv.getInt('daily.best.${dailySeed(yesterday)}'), 55);
      expect(p.dailyStreak, 1);
    });
  });

  group('saved game', () {
    test('round-trips an in-progress game', () async {
      final s = game(GameMode.classic, 12, over: false);
      await p.saveGame(s);
      expect(p.loadGame(GameMode.classic), s);
      expect(p.hasSavedGame(GameMode.daily), isFalse);
    });

    test('saving a finished game clears the slot', () async {
      await p.saveGame(game(GameMode.classic, 12, over: false));
      await p.saveGame(game(GameMode.classic, 20));
      expect(p.hasSavedGame(GameMode.classic), isFalse);
    });

    test('recording the end clears that mode only', () async {
      await p.saveGame(game(GameMode.classic, 12, over: false));
      await p.saveGame(game(GameMode.daily, 3, over: false));
      await p.recordGameEnd(game(GameMode.classic, 20));
      expect(p.hasSavedGame(GameMode.classic), isFalse);
      expect(p.hasSavedGame(GameMode.daily), isTrue);
    });

    test('yesterday\'s daily is discarded', () async {
      await p.saveGame(game(GameMode.daily, 3, over: false));
      now = now.add(const Duration(days: 1));
      expect(p.loadGame(GameMode.daily), isNull);
      expect(kv.containsKey('saved.daily'), isFalse);
    });

    test('corrupt, wrong-schema or wrong-mode saves are discarded', () async {
      await kv.setString('saved.classic', '{not json');
      expect(p.loadGame(GameMode.classic), isNull);

      final json = game(GameMode.classic, 1, over: false).toJson();
      await kv.setJson('saved.classic', {...json, 'v': 999});
      expect(p.loadGame(GameMode.classic), isNull);
      expect(kv.containsKey('saved.classic'), isFalse);

      await kv.setJson('saved.classic', {...json, 'board': 'oops'});
      expect(p.loadGame(GameMode.classic), isNull);

      await kv.setJson('saved.daily', json); // classic state in daily slot
      expect(p.loadGame(GameMode.daily), isNull);
    });
  });

  test('tutorial flag persists', () async {
    await p.setTutorialDone();
    expect(ProgressStore(kv, clock: () => now).tutorialDone, isTrue);
  });
}
