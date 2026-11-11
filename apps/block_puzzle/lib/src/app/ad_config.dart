import 'package:game_core/game_core.dart';

import '../constants.dart';

/// The block puzzle's interstitial caps, from the numbers in constants.dart.
const kAdPolicy = AdPolicy(
  minSecondsBetweenInterstitials: kInterstitialMinGapSeconds,
  freeGamesAfterInstall: kFreeGamesAfterInstall,
  minGameDuration: kMinGameDurationForInterstitial,
);
