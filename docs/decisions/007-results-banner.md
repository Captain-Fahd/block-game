# 007. Banner ad on the Results screen

Date: 2026-11-11
Status: accepted (Omar's decision)

## Context
The Phase 2 spec said "Banner: none at launch", to revisit after launch. Omar: "When the game over screen is displayed, add a banner ad at the top/bottom, wherever you see fit."

## Decision
- **Placement.** One anchored adaptive banner (`AdSize.getLargeAnchoredAdaptiveBannerAdSize`, full width) at the bottom of the Results screen, the screen titled "Game over" after the brief "No moves left" overlay. The score and buttons stay centred in the space above it.
- **Layout and policy.** Its height is reserved before the ad loads, so nothing jumps under the player's finger, and it sits well below Play again and Home. Accidental clicks near interactive elements are what AdMob policy penalises.
- **Never** during play, on the pause or game-over overlays, in the tutorial, or on Home.
- **Ad units.** Debug and profile builds use Google's adaptive test banner unit. Release builds use `ADMOB_BANNER_ID` from `env/prod.json` and show no banner if it's missing (never a test banner in production).
- **Consent.** Shown only once the Mobile Ads SDK is initialised, which happens only after UMP consent allows ad requests.
- **Interface.** `game_core` gets `AdsService.buildBanner()` (`FakeAdsService` returns a keyed placeholder for tests) and `AdUnitIds.banner`.

## Consequences
- Omar needs a third AdMob unit, a banner, in P6.8 (PLAN.md updated). `env/example.json` has `ADMOB_BANNER_ID`.
- More impressions per session. Watch retention after launch (Phase 10). If D1 or D7 drop, this is the first ad to reconsider.
- The Results screen also leads to the capped interstitial on Play again / Home, so a player may see a banner and then an interstitial. The interstitial caps (set in the spec) are unchanged.
