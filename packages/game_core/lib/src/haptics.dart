import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum HapticPattern {
  /// The subtlest tick, for moving across a grid or a picker.
  selection,
  light,
  medium,
  success,
}

abstract class Haptics {
  Future<void> play(HapticPattern pattern);
}

/// Platform haptics via [HapticFeedback]; does nothing when [enabled] is off.
class PlatformHaptics implements Haptics {
  PlatformHaptics(
    this.enabled, {
    this.successGap = const Duration(milliseconds: 90),
  });

  final ValueListenable<bool> enabled;
  final Duration successGap;

  @override
  Future<void> play(HapticPattern pattern) async {
    if (!enabled.value) return;
    switch (pattern) {
      case HapticPattern.selection:
        await HapticFeedback.selectionClick();
      case HapticPattern.light:
        await HapticFeedback.lightImpact();
      case HapticPattern.medium:
        await HapticFeedback.mediumImpact();
      case HapticPattern.success:
        await HapticFeedback.mediumImpact();
        await Future<void>.delayed(successGap);
        await HapticFeedback.heavyImpact();
    }
  }
}

class FakeHaptics implements Haptics {
  final List<HapticPattern> played = [];

  @override
  Future<void> play(HapticPattern pattern) async => played.add(pattern);
}
