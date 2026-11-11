import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart';
import 'package:game_core/game_core.dart';

import '../../constants.dart';
import '../block_game.dart';

/// Short-lived visual effects; cleared when a new game starts.
mixin TransientEffect on Component {}

/// A cleared block: flashes white, then shrinks away and bursts into
/// particles.
class ClearingBlock extends PositionComponent
    with TransientEffect, HasGameReference<BlockGame> {
  ClearingBlock({required this.colourIndex, required this.rect, this.delay = 0})
    : super(priority: 50);

  final int colourIndex;
  final Rect rect;
  final double delay;
  double _t = 0;
  bool _burst = false;

  static final Paint _flash = Paint();

  double get _total => delay + kClearFlashDuration + kClearShrinkDuration;

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (!_burst && _t >= delay + kClearFlashDuration) {
      _burst = true;
      _spawnParticles();
    }
    if (_t >= _total) removeFromParent();
  }

  void _spawnParticles() {
    final cell = game.layout.cell;
    final colours = game.colourBlind.value
        ? GameColors.blocksColourBlind
        : GameColors.blocks;
    final colour = colours[colourIndex % colours.length];
    final rand = math.Random();
    final paint = Paint()..color = colour;
    parent?.add(
      _Particles(
        Particle.generate(
          count: kParticlesPerCell,
          lifespan: kParticleLifespan,
          generator: (_) {
            final angle = rand.nextDouble() * math.pi * 2;
            final speed = (0.4 + rand.nextDouble() * 0.6) * kParticleSpeedCells;
            final side = cell * (0.12 + rand.nextDouble() * 0.12);
            return AcceleratedParticle(
              position: Vector2(rect.center.dx, rect.center.dy),
              speed:
                  Vector2(math.cos(angle), math.sin(angle) - 0.6) *
                  (speed * cell),
              acceleration: Vector2(0, kParticleGravityCells * cell),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  paint.color = colour.withValues(
                    alpha: (1 - particle.progress).clamp(0, 1),
                  );
                  canvas.drawRect(
                    Rect.fromCenter(
                      center: Offset.zero,
                      width: side,
                      height: side,
                    ),
                    paint,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (_t < 0) return;
    final local = _t - delay;
    if (local < 0) {
      // Waiting for the sweep to reach this cell: still drawn as a block.
      game.sprites.draw(canvas, colourIndex, rect);
      return;
    }
    if (local < kClearFlashDuration) {
      game.sprites.draw(canvas, colourIndex, rect);
      final a = 1 - local / kClearFlashDuration;
      _flash.color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * a);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect.deflate(rect.width * 0.04),
          Radius.circular(rect.width * 0.2),
        ),
        _flash,
      );
      return;
    }
    final p = ((local - kClearFlashDuration) / kClearShrinkDuration).clamp(
      0.0,
      1.0,
    );
    final s = 1 - p * p;
    if (s <= 0) return;
    final dst = Rect.fromCenter(
      center: rect.center,
      width: rect.width * s,
      height: rect.height * s,
    );
    game.sprites.draw(canvas, colourIndex, dst, opacity: s);
  }
}

class _Particles extends ParticleSystemComponent with TransientEffect {
  _Particles(Particle p) : super(particle: p, priority: 60);
}

/// Score text that floats up and fades out.
class FloatingText extends Component
    with TransientEffect, HasGameReference<BlockGame> {
  FloatingText(
    this.text,
    this.origin, {
    required this.fontSize,
    this.strong = false,
  }) : super(priority: 70);

  final String text;
  final Offset origin;
  final double fontSize;
  final bool strong;
  double _t = 0;
  late final TextPainter _painter;
  final Paint _layer = Paint();

  static TextStyle style(double fontSize, {required bool strong}) => TextStyle(
    fontFamily: kGameFontFamily,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    color: strong ? GameColors.accent : GameColors.textPrimary,
    shadows: const [Shadow(blurRadius: 6, color: Color(0xAA000000))],
  );

  @override
  Future<void> onLoad() async {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: style(fontSize, strong: strong),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _t += dt;
    if (_t >= kFloatingScoreDuration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / kFloatingScoreDuration).clamp(0.0, 1.0);
    final rise =
        kFloatingScoreRiseCells * game.layout.cell * (1 - (1 - p) * (1 - p));
    final alpha = p < 0.6 ? 1.0 : 1 - (p - 0.6) / 0.4;
    final pos = origin - Offset(_painter.width / 2, _painter.height / 2 + rise);
    _layer.color = Color.fromRGBO(0, 0, 0, alpha);
    canvas.saveLayer(
      Rect.fromLTWH(
        pos.dx - 8,
        pos.dy - 8,
        _painter.width + 16,
        _painter.height + 16,
      ),
      _layer,
    );
    _painter.paint(canvas, pos);
    canvas.restore();
  }
}

/// Draws every effect path once, at near-zero opacity, for the first few
/// frames after load, so the first real clear doesn't pay for first-use
/// GPU and text-layout setup (P4.7). Text sizes match [FloatingText] uses
/// in [BlockGame].
class Prewarm extends Component with HasGameReference<BlockGame> {
  Prewarm({this.frames = 3}) : super(priority: 1000);

  final int frames;
  int _drawn = 0;
  final List<TextPainter> _painters = [];
  final Paint _layer = Paint()..color = const Color(0x02000000);
  final Paint _flash = Paint()..color = const Color(0xD9FFFFFF);
  final Paint _particle = Paint()..color = const Color(0xFFFFFFFF);

  @override
  Future<void> onLoad() async {
    final cell = game.layout.cell;
    for (final (size, strong) in [
      (cell * 0.5, false),
      (cell * 0.7, true),
      (cell * 0.9, true),
    ]) {
      _painters.add(
        TextPainter(
          text: TextSpan(
            text: '+0123456789 x Board clear!',
            style: FloatingText.style(size, strong: strong),
          ),
          textDirection: TextDirection.ltr,
        )..layout(),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final cell = game.layout.cell;
    if (cell <= 0) return;
    final r = game.layout.cellRect(0, 0);
    canvas.saveLayer(game.layout.board, _layer);
    for (var i = 0; i < 8; i++) {
      game.sprites.draw(canvas, i, r, opacity: 0.5);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(cell * 0.2)),
      _flash,
    );
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, cell * 0.2, cell * 0.2),
      _particle,
    );
    var y = r.top;
    for (final p in _painters) {
      canvas.saveLayer(
        Rect.fromLTWH(r.left, y, p.width, p.height),
        Paint()..color = const Color(0x80000000),
      );
      p.paint(canvas, Offset(r.left, y));
      canvas.restore();
      y += p.height;
    }
    canvas.restore();
  }

  @override
  void update(double dt) {
    if (++_drawn >= frames) removeFromParent();
  }
}
