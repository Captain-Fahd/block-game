// Generates the game's sound effects as small 16-bit mono WAV files in
// assets/audio/. Everything is synthesised here, so there are no third-party
// assets or licences to track (ADR 004).
//
// Run from apps/block_puzzle: dart run tool/make_sfx.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int sampleRate = 22050;

void main() {
  final out = Directory('assets/audio')..createSync(recursive: true);
  final sounds = <String, List<double>>{
    'place.wav': place(),
    'clear.wav': clear(),
    'invalid.wav': invalid(),
    'game_over.wav': gameOver(),
    'new_best.wav': newBest(),
    'ui_tap.wav': uiTap(),
    'ui_toggle.wav': uiToggle(),
  };
  for (final e in sounds.entries) {
    final f = File('${out.path}/${e.key}');
    f.writeAsBytesSync(wav(e.value));
    print(
      '${f.path}  ${(e.value.length / sampleRate * 1000).round()} ms  '
      '${f.lengthSync()} bytes',
    );
  }
}

int _n(double seconds) => (seconds * sampleRate).round();

/// Short wooden "tock": a falling sine with a tiny noise click.
List<double> place() {
  final n = _n(0.07);
  final rand = math.Random(1);
  var phase = 0.0;
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final f = 520 - 2600 * t;
    phase += 2 * math.pi * f / sampleRate;
    final env = math.exp(-t * 55);
    final click = i < 60 ? (rand.nextDouble() * 2 - 1) * (1 - i / 60) * 0.3 : 0;
    return 0.75 * env * math.sin(phase) + click;
  });
}

/// Bright two-note chime (root + fifth) with a soft shimmer. The game raises
/// its playback rate with the streak.
List<double> clear() {
  final n = _n(0.32);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = math.exp(-t * 11) * math.min(1, t * 400);
    final shimmer = 1 + 0.15 * math.sin(2 * math.pi * 7 * t);
    final s =
        math.sin(2 * math.pi * 880 * t) * 0.5 +
        math.sin(2 * math.pi * 1320 * t) * 0.35 * shimmer +
        math.sin(2 * math.pi * 1760 * t) * 0.15 * math.exp(-t * 20);
    return 0.7 * env * s;
  });
}

/// Two soft low pulses: "nope".
List<double> invalid() {
  final n = _n(0.2);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final pulse = t < 0.08 ? t : (t >= 0.11 ? t - 0.11 : -1.0);
    if (pulse < 0) return 0;
    final env = math.exp(-pulse * 30) * math.min(1, pulse * 300);
    final x = math.sin(2 * math.pi * 160 * t);
    // Gentle saturation for a buzzier, still soft, tone.
    return 0.55 * env * (x + 0.3 * x * x * x);
  });
}

/// Menu tap: a very short, soft high tick (a damped sine with a gentle
/// attack, so there's no click).
List<double> uiTap() {
  final n = _n(0.035);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final env = math.exp(-t * 140) * math.min(1, t * 2000);
    return 0.6 * env * math.sin(2 * math.pi * 1650 * t);
  });
}

/// Toggle: two tiny rising blips. The game raises or lowers the rate for
/// on / off.
List<double> uiToggle() {
  final n = _n(0.09);
  return List.generate(n, (i) {
    final t = i / sampleRate;
    final second = t >= 0.04;
    final local = second ? t - 0.04 : t;
    final f = second ? 1320.0 : 990.0;
    final env = math.exp(-local * 90) * math.min(1, local * 2000);
    return 0.5 * env * math.sin(2 * math.pi * f * local);
  });
}

/// Three falling notes (C5, A4, F4) on a triangle wave.
List<double> gameOver() =>
    _notes(const [523.25, 440.0, 349.23], noteSeconds: 0.17, wave: _triangle);

/// Rising arpeggio (C5, E5, G5, C6) for a new best score.
List<double> newBest() => _notes(
  const [523.25, 659.25, 783.99, 1046.5],
  noteSeconds: 0.09,
  wave: math.sin,
  tail: 0.25,
);

double _triangle(double x) {
  final p = (x / (2 * math.pi)) % 1;
  return 4 * (p < 0.5 ? p : 1 - p) - 1;
}

List<double> _notes(
  List<double> freqs, {
  required double noteSeconds,
  required double Function(double) wave,
  double tail = 0.1,
}) {
  final total = _n(noteSeconds * freqs.length + tail);
  final out = List<double>.filled(total, 0);
  for (var k = 0; k < freqs.length; k++) {
    final start = _n(noteSeconds * k);
    final len = _n(noteSeconds + (k == freqs.length - 1 ? tail : 0.04));
    for (var i = 0; i < len && start + i < total; i++) {
      final t = i / sampleRate;
      final env = math.exp(-t * 9) * math.min(1, t * 300);
      out[start + i] += 0.5 * env * wave(2 * math.pi * freqs[k] * t);
    }
  }
  return out;
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
