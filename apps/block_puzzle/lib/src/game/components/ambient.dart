import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import '../../constants.dart';
import '../block_game.dart';
import '../glow.dart';

/// Lantern ambience behind the board (ADR 008): a warm pool of light that
/// flares briefly on clears, and a few faint lights drifting upward.
///
/// Uses a fixed seed, so golden images are deterministic.
class AmbientLight extends Component with HasGameReference<BlockGame> {
  AmbientLight({int seed = 7})
    : _rand = math.Random(seed),
      super(priority: -10);

  final math.Random _rand;
  final List<_Mote> _motes = [];
  double _flare = 0;
  double _time = 0;
  final Paint _pool = Paint();

  /// Brightens the pool for a moment; called when lines clear.
  void flare(int lines) {
    _flare = math.min(
      kBoardGlowFlareMax,
      _flare + lines * kBoardGlowFlarePerLine,
    );
  }

  double get flareLevel => _flare;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_motes.isEmpty) {
      for (var i = 0; i < kMoteCount; i++) {
        _motes.add(_Mote.random(_rand, startAnywhere: true));
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_flare > 0) {
      _flare = math.max(
        0,
        _flare - dt * (kBoardGlowFlareMax / kBoardGlowFlareDecay),
      );
    }
    final cell = game.layout.cell;
    if (cell <= 0) return;
    final height = game.size.y;
    for (final m in _motes) {
      m.y -= m.speed * cell * dt / height;
      if (m.y < -0.05) {
        m.reset(_rand);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    final l = game.layout;
    if (l.cell <= 0) return;
    final b = l.board;

    // Warm pool of light behind the board.
    final alpha = (kBoardGlowAlpha + _flare).clamp(0.0, 1.0);
    final radius = b.width * kBoardGlowRadius;
    _pool.shader = ui.Gradient.radial(
      b.center,
      radius,
      [
        kLanternAmber.withValues(alpha: alpha),
        kLanternAmber.withValues(alpha: alpha * 0.35),
        kLanternAmber.withValues(alpha: 0),
      ],
      const [0, 0.55, 1],
    );
    canvas.drawCircle(b.center, radius, _pool);

    // Drifting lights across the whole play column.
    final glow = game.glow;
    final w = game.size.x;
    final h = game.size.y;
    for (final m in _motes) {
      final sway = math.sin(_time * m.swaySpeed + m.phase) * l.cell * 0.25;
      final twinkle = 0.6 + 0.4 * math.sin(_time * m.twinkle + m.phase);
      glow.draw(
        canvas,
        Offset(m.x * w + sway, m.y * h),
        m.size * l.cell,
        kLanternAmber.withValues(alpha: m.alpha * twinkle),
      );
    }
  }
}

class _Mote {
  _Mote.random(math.Random r, {bool startAnywhere = false}) {
    reset(r);
    if (startAnywhere) y = r.nextDouble();
  }

  late double x; // 0..1 of width
  late double y; // 0..1 of height
  late double speed; // cells per second
  late double size; // cells
  late double alpha;
  late double phase;
  late double swaySpeed;
  late double twinkle;

  void reset(math.Random r) {
    x = r.nextDouble();
    y = 1.05;
    speed =
        kMoteMinSpeedCells +
        r.nextDouble() * (kMoteMaxSpeedCells - kMoteMinSpeedCells);
    size = kMoteMinSize + r.nextDouble() * (kMoteMaxSize - kMoteMinSize);
    alpha = kMoteMaxAlpha * (0.4 + 0.6 * r.nextDouble());
    phase = r.nextDouble() * math.pi * 2;
    swaySpeed = 0.4 + r.nextDouble() * 0.6;
    twinkle = 0.8 + r.nextDouble() * 1.4;
  }
}
