import 'package:game_core/game_core.dart';

import '../model/daily_seed.dart';
import '../model/game_state.dart';

/// Result of recording a finished game.
typedef GameEndRecord = ({
  int score,
  int previousBest,
  int best,
  bool newBest,
  int gamesPlayed,
  int dailyStreak,
});

/// Everything the block puzzle persists between launches, on top of
/// game_core's [KeyValueStore]: best scores, games played, the daily
/// streak, the tutorial flag and one saved game per mode.
class ProgressStore {
  ProgressStore(this._store, {this._clock = systemClock});

  final KeyValueStore _store;
  final Clock _clock;
  final _log = Logger('progress');

  static const _kBestClassic = 'best.classic';
  static const _kBestDaily = 'best.daily';
  static const _kDailyPrefix = 'daily.best.'; // + yyyymmdd
  static const _kGamesPlayed = 'stats.gamesPlayed';
  static const _kStreakCount = 'daily.streak.count';
  static const _kStreakLast = 'daily.streak.last'; // yyyymmdd
  static const _kTutorialDone = 'tutorial.done';
  static String _savedKey(GameMode m) => 'saved.${m.name}';

  DateTime get _today => _clock();
  int get todaySeed => dailySeed(_today);

  // --- Scores and stats ----------------------------------------------------

  int bestFor(GameMode mode) => switch (mode) {
    GameMode.classic => _store.getIntOr(_kBestClassic, 0),
    GameMode.daily => _store.getIntOr(_kBestDaily, 0),
  };

  /// Best daily score for today's puzzle (0 if not played today).
  int get todayDailyBest => _store.getIntOr('$_kDailyPrefix$todaySeed', 0);

  int get gamesPlayed => _store.getIntOr(_kGamesPlayed, 0);

  /// Consecutive days with a finished daily game. Still counts if the last
  /// one was yesterday (today's isn't played yet); 0 once a day is missed.
  int get dailyStreak {
    final last = _store.getInt(_kStreakLast);
    if (last == null) return 0;
    final gap = _daysBetween(last, todaySeed);
    return gap <= 1 ? _store.getIntOr(_kStreakCount, 0) : 0;
  }

  /// Records a finished game: best scores, games played, daily best and
  /// streak; clears that mode's saved game.
  Future<GameEndRecord> recordGameEnd(GameState s) async {
    final previousBest = bestFor(s.mode);
    final newBest = s.score > previousBest;
    if (newBest) {
      await _store.setInt(
        s.mode == GameMode.classic ? _kBestClassic : _kBestDaily,
        s.score,
      );
    }
    final played = gamesPlayed + 1;
    await _store.setInt(_kGamesPlayed, played);

    var streak = dailyStreak;
    if (s.mode == GameMode.daily) {
      // The game belongs to the date it was seeded with, even if it ends
      // after midnight.
      final dayKey = '$_kDailyPrefix${s.seed}';
      if (s.score > _store.getIntOr(dayKey, 0)) {
        await _store.setInt(dayKey, s.score);
      }
      streak = await _bumpStreak(s.seed);
    }
    await clearSavedGame(s.mode);
    return (
      score: s.score,
      previousBest: previousBest,
      best: newBest ? s.score : previousBest,
      newBest: newBest,
      gamesPlayed: played,
      dailyStreak: streak,
    );
  }

  Future<int> _bumpStreak(int day) async {
    final last = _store.getInt(_kStreakLast);
    final count = _store.getIntOr(_kStreakCount, 0);
    final int next;
    if (last == null) {
      next = 1;
    } else {
      final gap = _daysBetween(last, day);
      if (gap <= 0) {
        next = count; // same day (or an older game finishing late)
      } else if (gap == 1) {
        next = count + 1;
      } else {
        next = 1;
      }
    }
    if (last == null || _daysBetween(last, day) > 0) {
      await _store.setInt(_kStreakLast, day);
    }
    await _store.setInt(_kStreakCount, next);
    return next;
  }

  /// Whole days from yyyymmdd [a] to yyyymmdd [b].
  static int _daysBetween(int a, int b) =>
      _date(b).difference(_date(a)).inHours ~/ 24;

  static DateTime _date(int yyyymmdd) =>
      DateTime.utc(yyyymmdd ~/ 10000, (yyyymmdd ~/ 100) % 100, yyyymmdd % 100);

  // --- Tutorial --------------------------------------------------------------

  bool get tutorialDone => _store.getBoolOr(_kTutorialDone, false);
  Future<void> setTutorialDone() => _store.setBool(_kTutorialDone, true);

  // --- Saved game ------------------------------------------------------------

  /// Saves [s] for resuming; a finished game clears the slot instead.
  Future<void> saveGame(GameState s) async {
    if (s.isOver) {
      await clearSavedGame(s.mode);
      return;
    }
    await _store.setJson(_savedKey(s.mode), s.toJson());
  }

  /// The saved game for [mode], if there is one worth resuming: it parses,
  /// matches the schema, isn't finished, and (for daily) is today's puzzle.
  /// Anything else is discarded.
  GameState? loadGame(GameMode mode) {
    final json = _store.getJson(_savedKey(mode));
    if (json == null) return null;
    try {
      if (json['v'] != GameState.schemaVersion) throw const FormatException();
      final s = GameState.fromJson(json);
      if (s.mode != mode || s.isOver) throw const FormatException();
      if (mode == GameMode.daily && s.seed != todaySeed) {
        throw const FormatException();
      }
      return s;
    } on Object catch (e) {
      _log.info('discarding saved $mode game: $e');
      clearSavedGame(mode);
      return null;
    }
  }

  bool hasSavedGame(GameMode mode) => loadGame(mode) != null;

  Future<void> clearSavedGame(GameMode mode) => _store.remove(_savedKey(mode));
}
