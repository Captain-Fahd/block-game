import 'package:flutter/foundation.dart';

import 'storage.dart';

/// Player settings, persisted on every change.
class Settings {
  Settings(this._store)
    : sound = ValueNotifier(_store.getBoolOr(_kSound, true)),
      music = ValueNotifier(_store.getBoolOr(_kMusic, true)),
      haptics = ValueNotifier(_store.getBoolOr(_kHaptics, true)),
      colourBlindPatterns = ValueNotifier(
        _store.getBoolOr(_kColourBlind, false),
      ) {
    _persist(sound, _kSound);
    _persist(music, _kMusic);
    _persist(haptics, _kHaptics);
    _persist(colourBlindPatterns, _kColourBlind);
  }

  static const _kSound = 'settings.sound';
  static const _kMusic = 'settings.music';
  static const _kHaptics = 'settings.haptics';
  static const _kColourBlind = 'settings.colourBlindPatterns';

  final KeyValueStore _store;
  final ValueNotifier<bool> sound;
  final ValueNotifier<bool> music;
  final ValueNotifier<bool> haptics;
  final ValueNotifier<bool> colourBlindPatterns;

  void _persist(ValueNotifier<bool> n, String key) =>
      n.addListener(() => _store.setBool(key, n.value));

  void dispose() {
    sound.dispose();
    music.dispose();
    haptics.dispose();
    colourBlindPatterns.dispose();
  }
}
