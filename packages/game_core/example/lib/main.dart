import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

/// Device check for game_core (Phase 1 acceptance):
/// consent (EEA debug geography) → test interstitial → test rewarded.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'game_core check',
    theme: buildGameTheme(),
    home: const CheckScreen(),
  );
}

class CheckScreen extends StatefulWidget {
  const CheckScreen({super.key});

  @override
  State<CheckScreen> createState() => _CheckScreenState();
}

class _CheckScreenState extends State<CheckScreen> {
  // No caps here: this screen exists to see each ad format on a device.
  static const _policy = AdPolicy(
    minSecondsBetweenInterstitials: 0,
    freeGamesAfterInstall: 0,
    minGameDuration: Duration.zero,
  );

  final _ids = AdUnitIds.fromEnvironment();
  late final _consent = UmpConsentService(
    debugGeographyEea: true,
    testDeviceIds: _ids.testDeviceIds,
  );
  late final _ads = AdMobAdsService(
    consent: _consent,
    policy: _policy,
    ids: _ids,
  );
  final _log = <String>[];

  void _add(String line) => setState(() => _log.insert(0, line));

  Future<void> _gather() async {
    _add('Gathering consent (EEA debug geography)…');
    await _consent.gather();
    _add(
      'canRequestAds=${_consent.canRequestAds} '
      'privacyOptionsRequired=${_consent.privacyOptionsRequired}',
    );
    await _ads.initialize();
    _add('Ads initialised (test ids: ${_ids.isTest})');
  }

  Future<void> _interstitial() async {
    final shown = await _ads.maybeShowInterstitial(
      const InterstitialTrigger(
        name: 'example',
        completedGames: 99,
        gameDuration: Duration(minutes: 5),
      ),
    );
    _add('Interstitial shown: $shown');
  }

  Future<void> _rewarded() async {
    final earned = await _ads.showRewarded();
    _add('Rewarded earned: $earned');
  }

  Future<void> _privacy() async {
    await _consent.showPrivacyOptionsForm();
    _add('Privacy options closed');
  }

  Future<void> _reset() async {
    await _consent.resetForTesting();
    _add('Consent reset; tap "Gather consent" to see the form again');
  }

  @override
  void dispose() {
    _ads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(GameSpacing.md),
        child: Column(
          children: [
            Text(
              'game_core check',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: GameSpacing.md),
            GameButton(label: 'Gather consent', onPressed: _gather),
            const SizedBox(height: GameSpacing.sm),
            GameButton(
              label: 'Show interstitial',
              style: GameButtonStyle.secondary,
              onPressed: _interstitial,
            ),
            const SizedBox(height: GameSpacing.sm),
            ValueListenableBuilder<bool>(
              valueListenable: _ads.isRewardedReady,
              builder: (_, ready, _) => GameButton(
                label: ready ? 'Show rewarded' : 'Rewarded loading…',
                style: GameButtonStyle.secondary,
                onPressed: ready ? _rewarded : null,
              ),
            ),
            const SizedBox(height: GameSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    label: 'Privacy',
                    style: GameButtonStyle.secondary,
                    onPressed: _privacy,
                  ),
                ),
                const SizedBox(width: GameSpacing.sm),
                Expanded(
                  child: GameButton(
                    label: 'Reset',
                    style: GameButtonStyle.secondary,
                    onPressed: _reset,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GameSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  for (final l in _log)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        l,
                        style: const TextStyle(color: GameColors.textSecondary),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
