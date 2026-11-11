import 'package:flutter/widgets.dart';
import 'package:game_core/game_core.dart';

import '../data/progress_store.dart';
import '../game/sfx.dart';

/// Every service the app uses, behind game_core interfaces so tests can use
/// fakes. Provided to the widget tree by [ServicesScope].
class AppServices {
  AppServices({
    required this.store,
    required this.progress,
    required this.settings,
    required this.audio,
    required this.haptics,
    required this.consent,
    required this.ads,
    required this.analytics,
    this.clock = systemClock,
    this.privacyPolicyUrl = '',
    this.version = '',
    this.openUrl,
    this.newSeed,
  });

  final KeyValueStore store;
  final ProgressStore progress;
  final Settings settings;
  final AudioService<Sfx> audio;
  final Haptics haptics;
  final ConsentService consent;
  final AdsService ads;
  final Analytics analytics;
  final Clock clock;

  /// Empty until Omar's site is live; Settings hides the link then.
  final String privacyPolicyUrl;

  /// App version for Settings, e.g. `0.1.0 (1)`.
  final String version;

  /// Opens a URL outside the app (url_launcher in the real app).
  final Future<bool> Function(Uri uri)? openUrl;

  /// Seed for a new Classic game. Defaults to the clock, which is fine in
  /// the UI layer; the model only ever sees the number.
  final int Function()? newSeed;

  int classicSeed() =>
      newSeed?.call() ?? clock().microsecondsSinceEpoch & 0x7FFFFFFF;
}

class ServicesScope extends InheritedWidget {
  const ServicesScope({
    super.key,
    required this.services,
    required super.child,
  });

  final AppServices services;

  static AppServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ServicesScope>()!.services;

  @override
  bool updateShouldNotify(ServicesScope oldWidget) =>
      services != oldWidget.services;
}

/// Analytics events with their parameters, so names and keys live in one
/// place. No personal data.
abstract final class GameEvents {
  static Map<String, Object> mode(String mode) => {'mode': mode};

  static Map<String, Object> gameEnd({
    required String mode,
    required int score,
    required int durationSeconds,
    required int moves,
    required String cause,
  }) => {
    'mode': mode,
    'score': score,
    'duration_s': durationSeconds,
    'moves': moves,
    'cause': cause,
  };
}
