import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import 'logger.dart';

abstract class CrashReporter {
  /// Hooks [FlutterError.onError] and [PlatformDispatcher.onError] and routes
  /// release-mode [Logger] errors here.
  Future<void> install();
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  });
}

/// Crashlytics. Collection is disabled in debug builds.
class CrashlyticsReporter implements CrashReporter {
  CrashlyticsReporter([FirebaseCrashlytics? crashlytics])
    : _c = crashlytics ?? FirebaseCrashlytics.instance;

  final FirebaseCrashlytics _c;

  @override
  Future<void> install() async {
    await _c.setCrashlyticsCollectionEnabled(!kDebugMode);
    FlutterError.onError = _c.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _c.recordError(error, stack, fatal: true);
      return true;
    };
    Logger.errorSink = (message, error, stack) =>
        _c.recordError(error ?? message, stack, reason: message);
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) => _c.recordError(error, stack, fatal: fatal);
}

/// Used when Firebase isn't configured (tests, local builds without
/// google-services.json). Errors still reach the console via [Logger].
class NoopCrashReporter implements CrashReporter {
  final List<Object> recorded = [];

  @override
  Future<void> install() async {}

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async => recorded.add(error);
}
