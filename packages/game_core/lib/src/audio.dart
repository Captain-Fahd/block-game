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
///
/// Each effect gets [voicesPerSound] low-latency players created once in
/// [preload] and reused round-robin. (`FlameAudio.play` creates and loads a
/// new player for every call and never disposes it, which caused frame
/// spikes and a slow build-up of players on device.)
class FlameAudioService<S extends Enum> implements AudioService<S> {
  FlameAudioService({
    required this.files,
    required this.sound,
    required this.music,
    this.musicFile,
    this.musicVolume = 0.4,
    this.voicesPerSound = 3,
  }) {
    music.addListener(_onMusicSetting);
  }

  final Map<S, String> files;
  final ValueNotifier<bool> sound;
  final ValueNotifier<bool> music;
  final String? musicFile;
  final double musicVolume;
  final int voicesPerSound;
  final _log = Logger('audio');
  final Map<S, List<AudioPlayer>> _voices = {};
  final Map<S, int> _next = {};
  bool _musicWanted = false;
  bool _backgrounded = false;

  /// Sound effects mix with whatever else is playing (e.g. the player's own
  /// music) instead of taking audio focus.
  static final AudioContext _sfxContext = AudioContextConfig(
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  @override
  Future<void> preload() async {
    try {
      if (musicFile != null) await FlameAudio.audioCache.load(musicFile!);
    } on Object catch (e) {
      _log.warning('music preload failed', e);
    }
    for (final e in files.entries) {
      try {
        final voices = <AudioPlayer>[];
        for (var i = 0; i < voicesPerSound; i++) {
          final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
          await p.setAudioContext(_sfxContext);
          await p.setReleaseMode(ReleaseMode.stop);
          await p.setPlayerMode(PlayerMode.lowLatency);
          await p.setSource(AssetSource(e.value));
          voices.add(p);
        }
        _voices[e.key] = voices;
      } on Object catch (err) {
        _log.warning('preload ${e.key} failed', err);
      }
    }
  }

  @override
  Future<void> play(S sfx, {double volume = 1, double rate = 1}) async {
    if (!sound.value || _backgrounded) return;
    final voices = _voices[sfx];
    if (voices == null || voices.isEmpty) return;
    final i = _next[sfx] ?? 0;
    _next[sfx] = (i + 1) % voices.length;
    final p = voices[i];
    try {
      await p.stop();
      await p.setVolume(volume);
      await p.setPlaybackRate(rate);
      await p.resume();
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
    for (final voices in _voices.values) {
      for (final p in voices) {
        await p.dispose();
      }
    }
    _voices.clear();
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
