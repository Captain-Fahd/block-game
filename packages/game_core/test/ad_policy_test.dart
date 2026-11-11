import 'package:game_core/game_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const policy = AdPolicy(
    minSecondsBetweenInterstitials: 120,
    freeGamesAfterInstall: 2,
    minGameDuration: Duration(seconds: 30),
  );
  final t0 = DateTime(2027, 1, 1, 12);

  InterstitialTrigger trigger({
    int games = 5,
    int secs = 60,
    bool rewarded = false,
  }) => InterstitialTrigger(
    name: 'results_play_again',
    completedGames: games,
    gameDuration: Duration(seconds: secs),
    rewardedWatchedThisFlow: rewarded,
  );

  group('decideInterstitial', () {
    final cases =
        <(String, InterstitialTrigger, DateTime?, InterstitialDecision)>[
          (
            'game 1 is free',
            trigger(games: 1),
            null,
            InterstitialDecision.skipFreeGames,
          ),
          (
            'game 2 is free',
            trigger(games: 2),
            null,
            InterstitialDecision.skipFreeGames,
          ),
          (
            'game 3 can show',
            trigger(games: 3),
            null,
            InterstitialDecision.show,
          ),
          (
            '29 s game skipped',
            trigger(secs: 29),
            null,
            InterstitialDecision.skipShortGame,
          ),
          (
            '30 s game shows',
            trigger(secs: 30),
            null,
            InterstitialDecision.show,
          ),
          (
            'rewarded watched skips',
            trigger(rewarded: true),
            null,
            InterstitialDecision.skipRewardedWatched,
          ),
          (
            '119 s since last skips',
            trigger(),
            t0.subtract(const Duration(seconds: 119)),
            InterstitialDecision.skipTooSoon,
          ),
          (
            '120 s since last shows',
            trigger(),
            t0.subtract(const Duration(seconds: 120)),
            InterstitialDecision.show,
          ),
          (
            'free games win over everything',
            trigger(games: 1, secs: 5, rewarded: true),
            t0,
            InterstitialDecision.skipFreeGames,
          ),
        ];
    for (final (name, trig, last, expected) in cases) {
      test(name, () {
        expect(
          decideInterstitial(
            policy: policy,
            trigger: trig,
            now: t0,
            lastShownAt: last,
          ),
          expected,
        );
      });
    }
  });

  group('FakeAdsService with a fake clock', () {
    test('respects the time cap across calls', () async {
      var now = t0;
      final ads = FakeAdsService(policy: policy, clock: () => now);
      expect(await ads.maybeShowInterstitial(trigger()), isTrue);
      now = now.add(const Duration(seconds: 60));
      expect(await ads.maybeShowInterstitial(trigger()), isFalse);
      now = now.add(const Duration(seconds: 60));
      expect(await ads.maybeShowInterstitial(trigger()), isTrue);
      expect(ads.interstitialsShown.length, 2);
    });

    test('rewarded returns false when not ready or not earned', () async {
      final ads = FakeAdsService(policy: policy, rewardedReady: false);
      expect(ads.isRewardedReady.value, isFalse);
      expect(await ads.showRewarded(), isFalse);
      ads.rewardedReady = true;
      expect(await ads.showRewarded(), isTrue);
      ads.rewardEarned = false;
      expect(await ads.showRewarded(), isFalse);
      expect(ads.rewardedShown, 2);
      await ads.initialize();
      expect(ads.initializeCalls, 1);
      ads.dispose();
    });
  });

  group('AdUnitIds', () {
    test('debug builds always use test ids', () {
      final ids = AdUnitIds.resolve(
        interstitial: 'ca-app-pub-1/1',
        rewarded: 'ca-app-pub-1/2',
        testDevices: '',
        releaseMode: false,
      );
      expect(ids.interstitial, AdUnitIds.testInterstitial);
      expect(ids.rewarded, AdUnitIds.testRewarded);
      expect(ids.isTest, isTrue);
    });

    test('release uses real ids when both are present', () {
      final ids = AdUnitIds.resolve(
        interstitial: 'ca-app-pub-1/1',
        rewarded: 'ca-app-pub-1/2',
        testDevices: ' A , ,B',
        releaseMode: true,
      );
      expect(ids.interstitial, 'ca-app-pub-1/1');
      expect(ids.rewarded, 'ca-app-pub-1/2');
      expect(ids.testDeviceIds, ['A', 'B']);
      expect(ids.isTest, isFalse);
    });

    test('release falls back to test ids when ids are missing', () {
      final ids = AdUnitIds.resolve(
        interstitial: '',
        rewarded: 'x',
        testDevices: '',
        releaseMode: true,
      );
      expect(ids.isTest, isTrue);
      expect(AdUnitIds.fromEnvironment().isTest, isTrue);
    });
  });

  group('banner ids', () {
    test('debug always gets the test banner', () {
      final ids = AdUnitIds.resolve(
        interstitial: 'ca-app-pub-1/1',
        rewarded: 'ca-app-pub-1/2',
        banner: 'ca-app-pub-1/3',
        testDevices: '',
        releaseMode: false,
      );
      expect(ids.banner, AdUnitIds.testBanner);
    });

    test('release uses the configured banner', () {
      final ids = AdUnitIds.resolve(
        interstitial: 'ca-app-pub-1/1',
        rewarded: 'ca-app-pub-1/2',
        banner: 'ca-app-pub-1/3',
        testDevices: '',
        releaseMode: true,
      );
      expect(ids.banner, 'ca-app-pub-1/3');
    });

    test(
      'release with real ids but no banner id: no banner, never a test one',
      () {
        final ids = AdUnitIds.resolve(
          interstitial: 'ca-app-pub-1/1',
          rewarded: 'ca-app-pub-1/2',
          testDevices: '',
          releaseMode: true,
        );
        expect(ids.banner, isNull);
      },
    );
  });
}
