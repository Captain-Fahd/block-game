import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/widgets.dart';

import 'logger.dart';

/// Plays sound effects by enum id and one looping music track.
abstract class AudioService<S extends Enum> {
  Future<void> preload();

  /// [rate] changes pitch and speed together (e.g. rising clear sound).
  Future<void> play(S sfx, {double volume = 1, double rate = 1});
  Future<void> startMusic();
  Future<void> stopMusic();

  /// Pause/resume music when the app goes to the background.
  void onLifecycle(AppLifecycleState state);
  Future<void> dispose();
}

/// `flame_audio` implementation. [files] maps each id to a file under
/// `assets/audio/`. Respects the [sound] and [music] settings.
class FlameAudioService<S extends Enum> implements AudioService<S> {
  FlameAudioService({
    required this.files,
    required this.sound,
    required this.music,
    this.musicFile,
    this.musicVolume = 0.4,
  }) {
    music.addListener(_onMusicSetting);
  }

  final Map<S, String> files;
  final ValueNotifier<bool> sound;
  final ValueNotifier<bool> music;
  final String? musicFile;
  final double musicVolume;
  final _log = Logger('audio');
  bool _musicWanted = false;
  bool _backgrounded = false;

  @override
  Future<void> preload() async {
    try {
      await FlameAudio.audioCache.loadAll([...files.values, ?musicFile]);
    } on Object catch (e) {
      _log.warning('preload failed', e);
    }
  }

  @override
  Future<void> play(S sfx, {double volume = 1, double rate = 1}) async {
    if (!sound.value || _backgrounded) return;
    final file = files[sfx];
    if (file == null) return;
    try {
      final player = await FlameAudio.play(file, volume: volume);
      if (rate != 1) await player.setPlaybackRate(rate);
    } on Object catch (e) {
      _log.warning('play $sfx failed', e);
    }
  }

  @override
  Future<void> startMusic() async {
    _musicWanted = true;
    await _syncMusic();
  }

  @override
  Future<void> stopMusic() async {
    _musicWanted = false;
    await _syncMusic();
  }

  void _onMusicSetting() => _syncMusic();

  Future<void> _syncMusic() async {
    if (musicFile == null) return;
    try {
      final shouldPlay = _musicWanted && music.value && !_backgrounded;
      if (shouldPlay) {
        if (FlameAudio.bgm.isPlaying) {
          await FlameAudio.bgm.resume();
        } else {
          await FlameAudio.bgm.play(musicFile!, volume: musicVolume);
        }
      } else if (FlameAudio.bgm.isPlaying) {
        await FlameAudio.bgm.pause();
      }
    } on Object catch (e) {
      _log.warning('music failed', e);
    }
  }

  @override
  void onLifecycle(AppLifecycleState state) {
    _backgrounded = state != AppLifecycleState.resumed;
    _syncMusic();
  }

  @override
  Future<void> dispose() async {
    music.removeListener(_onMusicSetting);
    await FlameAudio.bgm.stop();
  }
}

/// Records calls; plays nothing.
class FakeAudioService<S extends Enum> implements AudioService<S> {
  final List<(S, double)> played = [];
  bool musicPlaying = false;
  AppLifecycleState? lastLifecycle;

  @override
  Future<void> preload() async {}
  @override
  Future<void> play(S sfx, {double volume = 1, double rate = 1}) async =>
      played.add((sfx, rate));
  @override
  Future<void> startMusic() async => musicPlaying = true;
  @override
  Future<void> stopMusic() async => musicPlaying = false;
  @override
  void onLifecycle(AppLifecycleState state) => lastLifecycle = state;
  @override
  Future<void> dispose() async {}
}
