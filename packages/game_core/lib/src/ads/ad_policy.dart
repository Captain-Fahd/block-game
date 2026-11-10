import 'package:meta/meta.dart';

/// Interstitial frequency caps. Each game passes its own values from its
/// `constants.dart`.
@immutable
class AdPolicy {
  const AdPolicy({
    required this.minSecondsBetweenInterstitials,
    required this.freeGamesAfterInstall,
    required this.minGameDuration,
  });

  /// At least this long since the last interstitial.
  final int minSecondsBetweenInterstitials;

  /// No interstitial after any of the first N completed games of an install.
  final int freeGamesAfterInstall;

  /// Skip if the game that just ended was shorter than this.
  final Duration minGameDuration;
}

/// Context for one "may we show an interstitial now?" decision.
@immutable
class InterstitialTrigger {
  const InterstitialTrigger({
    required this.name,
    required this.completedGames,
    required this.gameDuration,
    this.rewardedWatchedThisFlow = false,
  });

  /// For analytics, e.g. `results_play_again`.
  final String name;

  /// Games completed since install, including the one that just ended.
  final int completedGames;
  final Duration gameDuration;
  final bool rewardedWatchedThisFlow;
}

enum InterstitialDecision {
  show,
  skipFreeGames,
  skipTooSoon,
  skipShortGame,
  skipRewardedWatched,
}

/// Pure cap logic, tested with a fake clock.
InterstitialDecision decideInterstitial({
  required AdPolicy policy,
  required InterstitialTrigger trigger,
  required DateTime now,
  required DateTime? lastShownAt,
}) {
  if (trigger.completedGames <= policy.freeGamesAfterInstall) {
    return InterstitialDecision.skipFreeGames;
  }
  if (trigger.rewardedWatchedThisFlow) {
    return InterstitialDecision.skipRewardedWatched;
  }
  if (trigger.gameDuration < policy.minGameDuration) {
    return InterstitialDecision.skipShortGame;
  }
  if (lastShownAt != null &&
      now.difference(lastShownAt).inSeconds <
          policy.minSecondsBetweenInterstitials) {
    return InterstitialDecision.skipTooSoon;
  }
  return InterstitialDecision.show;
}
