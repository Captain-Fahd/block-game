import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

/// Receives errors in release builds (wired to Crashlytics by the app).
typedef ErrorSink = void Function(
  String message,
  Object? error,
  StackTrace? stack,
);

/// Thin tagged logger. In debug/profile everything at or above [minLevel]
/// goes to [output]. In release nothing is printed; errors go to [errorSink].
class Logger {
  Logger(this.tag);

  final String tag;

  static LogLevel minLevel = LogLevel.debug;
  static ErrorSink? errorSink;
  static bool releaseMode = kReleaseMode;

  /// Where non-release logs go. Replaceable in tests.
  static void Function(String line) output = (line) => debugPrint(line);

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message, [Object? error]) =>
      _log(LogLevel.warning, message, error);
  void error(String message, [Object? error, StackTrace? stack]) =>
      _log(LogLevel.error, message, error, stack);

  void _log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    if (releaseMode) {
      if (level == LogLevel.error) {
        errorSink?.call('[$tag] $message', error, stack);
      }
      return;
    }
    if (level.index < minLevel.index) return;
    final suffix = error == null ? '' : ' | $error';
    output('${level.name.toUpperCase()} [$tag] $message$suffix');
    if (stack != null) output(stack.toString());
  }
}
