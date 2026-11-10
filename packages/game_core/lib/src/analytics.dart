import 'package:firebase_analytics/firebase_analytics.dart';

import 'logger.dart';

/// Event names shared by all games. Parameters never carry personal data.
abstract final class AnalyticsEvents {
  static const gameStart = 'game_start';

  /// Params: score, duration_s, moves, cause.
  static const gameEnd = 'game_end';
  static const levelClear = 'level_clear';
  static const lineClear = 'line_clear';
  static const adInterstitialShown = 'ad_interstitial_shown';
  static const adRewardedOffered = 'ad_rewarded_offered';
  static const adRewardedCompleted = 'ad_rewarded_completed';
  static const tutorialComplete = 'tutorial_complete';
  static const dailyStart = 'daily_start';
  static const dailyEnd = 'daily_end';
}

abstract class Analytics {
  Future<void> logEvent(String name, [Map<String, Object> params = const {}]);
}

class FirebaseAnalyticsService implements Analytics {
  FirebaseAnalyticsService([FirebaseAnalytics? analytics])
    : _fa = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _fa;
  final _log = Logger('analytics');

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> params = const {},
  ]) async {
    try {
      await _fa.logEvent(
        name: name,
        parameters: params.isEmpty ? null : params,
      );
    } on Object catch (e) {
      _log.warning('logEvent $name failed', e);
    }
  }
}

class NoopAnalytics implements Analytics {
  const NoopAnalytics();

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> params = const {},
  ]) async {}
}

/// Records events for tests.
class RecordingAnalytics implements Analytics {
  final List<(String, Map<String, Object>)> events = [];

  Iterable<String> get names => events.map((e) => e.$1);

  @override
  Future<void> logEvent(
    String name, [
    Map<String, Object> params = const {},
  ]) async => events.add((name, params));
}
