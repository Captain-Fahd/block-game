import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/app/app.dart';
import 'src/app/services.dart';
import 'src/constants.dart';
import 'src/data/progress_store.dart';
import 'src/game/autoplay.dart';
import 'src/game/sfx.dart';
import 'src/model/game_state.dart';
import 'src/ui/game_screen.dart';

const _kPrivacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');

const kAdPolicy = AdPolicy(
  minSecondsBetweenInterstitials: kInterstitialMinGapSeconds,
  freeGamesAfterInstall: kFreeGamesAfterInstall,
  minGameDuration: kMinGameDurationForInterstitial,
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  registerGameCoreLicenses();

  final store = await SharedPrefsStore.open();
  final settings = Settings(store);
  if (kAutoplayMute) settings.sound.value = false;
  final audio = FlameAudioService<Sfx>(
    files: kSfxFiles,
    sound: settings.sound,
    music: settings.music,
  );
  unawaited(audio.preload());
  final info = await PackageInfo.fromPlatform();

  final ids = AdUnitIds.fromEnvironment();
  final consent = UmpConsentService(testDeviceIds: ids.testDeviceIds);
  // Phase 6 (P6.1) swaps in AdMobAdsService. Until then no rewarded ad is
  // ever ready, so the second-chance offer stays hidden, per the spec.
  final ads = FakeAdsService(policy: kAdPolicy, rewardedReady: false);

  final services = AppServices(
    store: store,
    progress: ProgressStore(store),
    settings: settings,
    audio: audio,
    haptics: PlatformHaptics(settings.haptics),
    consent: consent,
    ads: ads,
    analytics: const NoopAnalytics(), // Firebase in P6.4
    privacyPolicyUrl: _kPrivacyPolicyUrl,
    version: '${info.version} (${info.buildNumber})',
    openUrl: (uri) => launchUrl(uri, mode: LaunchMode.externalApplication),
  );

  if (kAutoplay) {
    FrameStats().start();
    runApp(
      BlockPuzzleApp(
        services: services,
        home: Builder(
          builder: (context) => GameScreen.newGame(services, GameMode.classic),
        ),
      ),
    );
    return;
  }

  runApp(BlockPuzzleApp(services: services));

  // Consent after the first frame and never awaited before UI, so an
  // offline launch can't hang on it. Ads initialise only if consent allows.
  unawaited(consent.gather().then((_) => ads.initialize()));
}
