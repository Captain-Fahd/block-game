import 'package:flutter/foundation.dart';

/// Ad unit ids. Real ids come only from `--dart-define-from-file=env/*.json`
/// and are used only in release builds; everything else gets Google's
/// sample test ids.
@immutable
class AdUnitIds {
  const AdUnitIds({
    required this.interstitial,
    required this.rewarded,
    this.testDeviceIds = const [],
  });

  /// Reads `ADMOB_INTERSTITIAL_ID`, `ADMOB_REWARDED_ID` and
  /// `ADMOB_TEST_DEVICE_IDS` (comma-separated) from dart-defines.
  factory AdUnitIds.fromEnvironment({bool releaseMode = kReleaseMode}) {
    const interstitial = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
    const rewarded = String.fromEnvironment('ADMOB_REWARDED_ID');
    const devices = String.fromEnvironment('ADMOB_TEST_DEVICE_IDS');
    return resolve(
      interstitial: interstitial,
      rewarded: rewarded,
      testDevices: devices,
      releaseMode: releaseMode,
    );
  }

  @visibleForTesting
  static AdUnitIds resolve({
    required String interstitial,
    required String rewarded,
    required String testDevices,
    required bool releaseMode,
  }) {
    final useReal =
        releaseMode && interstitial.isNotEmpty && rewarded.isNotEmpty;
    return AdUnitIds(
      interstitial: useReal ? interstitial : testInterstitial,
      rewarded: useReal ? rewarded : testRewarded,
      testDeviceIds: [
        for (final id in testDevices.split(','))
          if (id.trim().isNotEmpty) id.trim(),
      ],
    );
  }

  // Google's public sample ad units for Android.
  static const testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  final String interstitial;
  final String rewarded;
  final List<String> testDeviceIds;

  bool get isTest => interstitial == testInterstitial;
}
