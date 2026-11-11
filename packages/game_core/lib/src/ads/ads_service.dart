import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../clock.dart';
import '../consent.dart';
import '../logger.dart';
import '../storage.dart';
import 'ad_ids.dart';
import 'ad_policy.dart';

abstract class AdsService {
  /// Initialises the SDK if consent allows, then preloads ads. Safe to call
  /// again after consent changes.
  Future<void> initialize();

  /// Shows an interstitial if [AdPolicy] caps allow and one is loaded.
  /// Returns true if an ad was shown (and dismissed).
  Future<bool> maybeShowInterstitial(InterstitialTrigger trigger);

  /// Shows a rewarded ad. True only if the reward was earned.
  Future<bool> showRewarded();

  /// Whether a rewarded ad is loaded, so the UI can hide the offer.
  ValueListenable<bool> get isRewardedReady;

  /// A full-width anchored adaptive banner. Reserves its height before the
  /// ad loads (so nothing jumps). Empty when banners aren't available (no
  /// consent yet, or no banner unit configured).
  Widget buildBanner();

  void dispose();
}

class AdMobAdsService implements AdsService {
  AdMobAdsService({
    required this.consent,
    required this.policy,
    required this.ids,
    this.clock = systemClock,
    this.retryDelay = const Duration(seconds: 30),
    this.store,
  });

  /// Optional: persists the last interstitial time so the minimum gap holds
  /// across app restarts.
  final KeyValueStore? store;
  static const _kLastInterstitial = 'ads.lastInterstitialMs';

  final ConsentService consent;
  final AdPolicy policy;
  final AdUnitIds ids;
  final Clock clock;
  final Duration retryDelay;
  final _log = Logger('ads');

  final _rewardedReady = ValueNotifier<bool>(false);
  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;
  DateTime? _lastInterstitialAt;
  bool _initialized = false;
  bool _disposed = false;
  Timer? _interstitialRetry;
  Timer? _rewardedRetry;

  @override
  ValueListenable<bool> get isRewardedReady => _rewardedReady;

  /// Last interstitial shown, this session or (with [store]) a previous one.
  DateTime? get lastInterstitialAt {
    if (_lastInterstitialAt != null) return _lastInterstitialAt;
    final ms = store?.getInt(_kLastInterstitial);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> initialize() async {
    if (_initialized || !consent.canRequestAds) return;
    _initialized = true;
    try {
      await MobileAds.instance.initialize();
      if (ids.testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: ids.testDeviceIds),
        );
      }
    } on Object catch (e) {
      _log.warning('init failed', e);
      _initialized = false;
      return;
    }
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    if (_disposed || !_initialized) return;
    InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          _log.info('interstitial no fill: ${error.code}');
          _interstitialRetry?.cancel();
          _interstitialRetry = Timer(retryDelay, _loadInterstitial);
        },
      ),
    );
  }

  void _loadRewarded() {
    if (_disposed || !_initialized) return;
    RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          _log.info('rewarded no fill: ${error.code}');
          _rewardedReady.value = false;
          _rewardedRetry?.cancel();
          _rewardedRetry = Timer(retryDelay, _loadRewarded);
        },
      ),
    );
  }

  @override
  Future<bool> maybeShowInterstitial(InterstitialTrigger trigger) async {
    final decision = decideInterstitial(
      policy: policy,
      trigger: trigger,
      now: clock(),
      lastShownAt: lastInterstitialAt,
    );
    if (decision != InterstitialDecision.show) {
      _log.debug('interstitial ${trigger.name}: ${decision.name}');
      return false;
    }
    final ad = _interstitial;
    if (ad == null) return false;
    _interstitial = null;

    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        final now = clock();
        _lastInterstitialAt = now;
        store?.setInt(_kLastInterstitial, now.millisecondsSinceEpoch);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(true);
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadInterstitial();
      },
    );
    await ad.show();
    return done.future;
  }

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    _rewardedReady.value = false;

    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!done.isCompleted) done.complete(earned);
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        if (!done.isCompleted) done.complete(false);
        _loadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Widget buildBanner() {
    final unit = ids.banner;
    if (!_initialized || unit == null) return const SizedBox.shrink();
    return _AdMobBanner(adUnitId: unit);
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitial?.dispose();
    _rewarded?.dispose();
    _rewardedReady.dispose();
  }
}

class _AdMobBanner extends StatefulWidget {
  const _AdMobBanner({required this.adUnitId});

  final String adUnitId;

  @override
  State<_AdMobBanner> createState() => _AdMobBannerState();
}

class _AdMobBannerState extends State<_AdMobBanner> {
  final _log = Logger('ads');
  AdSize? _size;
  BannerAd? _ad;
  bool _loaded = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _load(int width) async {
    final size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(width);
    if (!mounted || size == null) return;
    setState(() => _size = size); // reserve the space first
    final ad = BannerAd(
      adUnitId: widget.adUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          _log.info('banner no fill: ${error.code}');
          ad.dispose();
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    if (size == null) return const SizedBox.shrink();
    return SizedBox(
      width: size.width.toDouble(),
      height: size.height.toDouble(),
      child: _loaded && _ad != null ? AdWidget(ad: _ad!) : null,
    );
  }
}

/// Test double: applies the same cap logic, shows nothing.
class FakeAdsService implements AdsService {
  FakeAdsService({
    required this.policy,
    this.clock = systemClock,
    bool rewardedReady = true,
    this.rewardEarned = true,
  }) : _rewardedReady = ValueNotifier(rewardedReady);

  final AdPolicy policy;
  final Clock clock;
  bool rewardEarned;
  final ValueNotifier<bool> _rewardedReady;
  DateTime? lastInterstitialAt;
  final List<String> interstitialsShown = [];
  int rewardedShown = 0;
  int initializeCalls = 0;

  set rewardedReady(bool v) => _rewardedReady.value = v;

  @override
  ValueListenable<bool> get isRewardedReady => _rewardedReady;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  Future<bool> maybeShowInterstitial(InterstitialTrigger trigger) async {
    final decision = decideInterstitial(
      policy: policy,
      trigger: trigger,
      now: clock(),
      lastShownAt: lastInterstitialAt,
    );
    if (decision != InterstitialDecision.show) return false;
    lastInterstitialAt = clock();
    interstitialsShown.add(trigger.name);
    return true;
  }

  @override
  Future<bool> showRewarded() async {
    if (!_rewardedReady.value) return false;
    rewardedShown++;
    return rewardEarned;
  }

  /// Whether [buildBanner] returns the placeholder.
  bool bannerAvailable = true;

  @override
  Widget buildBanner() => bannerAvailable
      ? const SizedBox(key: Key('fakeBanner'), height: 50)
      : const SizedBox.shrink();

  @override
  void dispose() => _rewardedReady.dispose();
}
