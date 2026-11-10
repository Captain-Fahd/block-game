import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'logger.dart';

/// UMP consent (GDPR / US state privacy messages).
abstract class ConsentService {
  /// Requests a consent info update and shows the form if required. Call on
  /// every launch. Never throws. The network request is time-limited, so an
  /// offline launch carries on; if a form is shown, this completes when the
  /// player dismisses it.
  Future<void> gather();

  /// Whether ads may be requested (from this or a previous session).
  bool get canRequestAds;

  /// Whether Settings must show a "Privacy options" entry.
  bool get privacyOptionsRequired;

  Future<void> showPrivacyOptionsForm();
}

class UmpConsentService implements ConsentService {
  UmpConsentService({
    this.debugGeographyEea = false,
    this.testDeviceIds = const [],
    this.timeout = const Duration(seconds: 8),
  });

  /// Debug builds only: pretend the device is in the EEA to test the form.
  final bool debugGeographyEea;
  final List<String> testDeviceIds;
  final Duration timeout;
  final _log = Logger('consent');

  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;

  @override
  bool get canRequestAds => _canRequestAds;
  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  ConsentRequestParameters _params() {
    if (kReleaseMode) return ConsentRequestParameters();
    return ConsentRequestParameters(
      consentDebugSettings: ConsentDebugSettings(
        debugGeography: debugGeographyEea
            ? DebugGeography.debugGeographyEea
            : DebugGeography.debugGeographyDisabled,
        testIdentifiers: testDeviceIds,
      ),
    );
  }

  @override
  Future<void> gather() async {
    // Only the network round-trip is time-limited. Once the form is on
    // screen we wait for the player however long they take; timing out
    // there would read stale status and skip ads for the whole session.
    final infoUpdated = Completer<bool>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      _params(),
      () {
        if (!infoUpdated.isCompleted) infoUpdated.complete(true);
      },
      (FormError error) {
        _log.warning('info update failed: ${error.message}');
        if (!infoUpdated.isCompleted) infoUpdated.complete(false);
      },
    );
    final bool updated;
    try {
      updated = await infoUpdated.future.timeout(timeout);
    } on TimeoutException {
      _log.warning('consent info update timed out');
      await _refresh();
      return;
    }
    if (updated) {
      final formDone = Completer<void>();
      ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
        if (error != null) _log.warning('form: ${error.message}');
        if (!formDone.isCompleted) formDone.complete();
      });
      await formDone.future;
    }
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final info = ConsentInformation.instance;
      _canRequestAds = await info.canRequestAds();
      _privacyOptionsRequired =
          await info.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } on Object catch (e) {
      _log.warning('consent status failed', e);
    }
  }

  @override
  Future<void> showPrivacyOptionsForm() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) _log.warning('privacy form: ${error.message}');
      done.complete();
    });
    await done.future;
    await _refresh();
  }

  /// Debug helper: forget consent so the form shows again.
  Future<void> resetForTesting() => ConsentInformation.instance.reset();
}

class FakeConsentService implements ConsentService {
  FakeConsentService({
    this.canRequestAds = true,
    this.privacyOptionsRequired = false,
  });

  @override
  bool canRequestAds;
  @override
  bool privacyOptionsRequired;
  int gatherCalls = 0;
  int privacyFormShows = 0;

  @override
  Future<void> gather() async => gatherCalls++;
  @override
  Future<void> showPrivacyOptionsForm() async => privacyFormShows++;
}
