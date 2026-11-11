// Generates the game's sound effects as small 16-bit mono WAV files in
// assets/audio/. Everything is synthesised here, so there are no third-party
// assets or licences to track (ADR 004).
//
// All sounds share one voice, a soft mallet (warm fundamental plus a small,
// fast-fading overtone, nothing above ~2 kHz), and use notes from C major
// pentatonic, so they sound like one family. Each file is peak-normalised
// to a per-sound level so loudness is consistent.
//
// Run from apps/block_puzzle: dart run tool/make_sfx.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

// C major pentatonic, Hz.
const double a3 = 220.00;
const double c4 = 261.63;
const double d4 = 293.66;
const double e4 = 329.63;
const double g4 = 392.00;
const double a4 = 440.00;
const double c5 = 523.25;
const double e5 = 659.25;

void main() {
  final out = Directory('assets/audio')..createSync(recursive: true);
  // name -> (samples, peak level)
  final sounds = <String, (List<double>, double)>{
    'place.wav': (place(), 0.55),
    'clear.wav': (clear(), 0.6),
    'invalid.wav': (invalid(), 0.45),
    'game_over.wav': (gameOver(), 0.55),
    'new_best.wav': (newBest(), 0.6),
    'ui_tap.wav': (uiTap(), 0.5),
    'ui_toggle.wav': (uiToggle(), 0.5),
  };
  for (final e in sounds.entries) {
    final (samples, peak) = e.value;
    final f = File('${out.path}/${e.key}');
    f.writeAsBytesSync(wav(normalise(samples, peak)));
    print(
      '${f.path}  ${(samples.length / sampleRate * 1000).round()} ms  '
      '${f.lengthSync()} bytes',
    );
  }
}

int _n(double seconds) => (seconds * sampleRate).round();

List<double> _buf(double seconds) => List<double>.filled(_n(seconds), 0);

/// Adds one mallet note to [buf].
///
/// [decay] is the amplitude decay rate (1/s): higher = shorter, more muted.
/// The overtone (2x, quieter, decaying faster) gives a wooden "mallet"
/// colour without the brightness of extra harmonics.
void mallet(
  List<double> buf,
  double freq, {
  double start = 0,
  double decay = 12,
  double gain = 1,
  double overtone = 0.22,
}) {
  final s0 = _n(start);
  for (var i = 0; s0 + i < buf.length; i++) {
    final t = i / sampleRate;
    final attack = math.min(1.0, t / 0.004); // 4 ms: no click
    final env = attack * math.exp(-t * decay);
    if (env < 1e-4 && t > 0.01) break;
    final v =
        math.sin(2 * math.pi * freq * t) +
        overtone *
            math.exp(-t * decay * 2.5) *
            math.sin(2 * math.pi * 2 * freq * t);
    buf[s0 + i] += gain * env * v;
  }
}

/// Placing a piece: one short, soft knock.
List<double> place() {
  final b = _buf(0.12);
  mallet(b, c4, decay: 38, overtone: 0.35);
  return b;
}

/// Clearing lines: a quick upward strum, low-mid and warm. The game shifts
/// its pitch up by musical intervals as the streak grows.
List<double> clear() {
  final b = _buf(0.6);
  const notes = [c4, e4, g4, c5];
  for (var i = 0; i < notes.length; i++) {
    mallet(b, notes[i], start: i * 0.035, decay: 7, gain: i == 3 ? 0.8 : 1);
  }
  return b;
}

/// Invalid drop: two soft, damped falling notes.
List<double> invalid() {
  final b = _buf(0.22);
  mallet(b, d4, decay: 30, overtone: 0.1);
  mallet(b, a3, start: 0.08, decay: 30, overtone: 0.1);
  return b;
}

/// Game over: slow falling G4, E4, C4.
List<double> gameOver() {
  final b = _buf(1.0);
  mallet(b, g4, decay: 6);
  mallet(b, e4, start: 0.2, decay: 6);
  mallet(b, c4, start: 0.4, decay: 4.5);
  return b;
}

/// New best: quick rising C4, E4, G4, C5, E5.
List<double> newBest() {
  final b = _buf(0.75);
  const notes = [c4, e4, g4, c5, e5];
  for (var i = 0; i < notes.length; i++) {
    mallet(b, notes[i], start: i * 0.07, decay: i == 4 ? 6 : 10, gain: 0.9);
  }
  return b;
}

/// Menu tap: the same mallet, very short.
List<double> uiTap() {
  final b = _buf(0.06);
  mallet(b, a4, decay: 70, overtone: 0.15);
  return b;
}

/// Toggle: two short notes (G4 to C5). The game plays it a bit higher for
/// on and lower for off.
List<double> uiToggle() {
  final b = _buf(0.14);
  mallet(b, g4, decay: 45, overtone: 0.15);
  mallet(b, c5, start: 0.045, decay: 45, overtone: 0.15);
  return b;
}

/// Scales [samples] so the loudest point is [peak] (0..1).
List<double> normalise(List<double> samples, double peak) {
  final max = samples.fold<double>(0, (m, v) => math.max(m, v.abs()));
  if (max == 0) return samples;
  final k = peak / max;
  return [for (final v in samples) v * k];
}

/// 16-bit PCM mono WAV. Fades the last 5 ms to avoid a click.
Uint8List wav(List<double> samples) {
  final fade = _n(0.005);
  final n = samples.length;
  final data = ByteData(n * 2);
  for (var i = 0; i < n; i++) {
    var s = samples[i];
    if (i > n - fade) s *= (n - i) / fade;
    data.setInt16(i * 2, (s.clamp(-1.0, 1.0) * 32767).round(), Endian.little);
  }
  final h = ByteData(44);
  void str(int o, String s) {
    for (var i = 0; i < 4; i++) {
      h.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  h.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  h.setUint32(16, 16, Endian.little);
  h.setUint16(20, 1, Endian.little); // PCM
  h.setUint16(22, 1, Endian.little); // mono
  h.setUint32(24, sampleRate, Endian.little);
  h.setUint32(28, sampleRate * 2, Endian.little);
  h.setUint16(32, 2, Endian.little);
  h.setUint16(34, 16, Endian.little);
  str(36, 'data');
  h.setUint32(40, n * 2, Endian.little);
  return Uint8List.fromList([
    ...h.buffer.asUint8List(),
    ...data.buffer.asUint8List(),
  ]);
}
