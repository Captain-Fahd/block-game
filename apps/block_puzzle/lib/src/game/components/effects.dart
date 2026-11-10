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
  ClearingBlock({
    required this.colourIndex,
    required this.rect,
    this.delay = 0,
    this.invisible = false,
  }) : super(priority: 50);

  /// Drawn off-screen and invisible once at load, so the first real clear
  /// doesn't pay for first-use setup (particles, shaders, paints).
  ClearingBlock.prewarm()
    : this(
        colourIndex: 0,
        rect: const Rect.fromLTWH(-500, -500, 10, 10),
        invisible: true,
      );

  final int colourIndex;
  final Rect rect;
  final double delay;
  final bool invisible;
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
          count: invisible ? 1 : kParticlesPerCell,
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
                  if (invisible) return;
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
    if (invisible || _t < 0) return;
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

  @override
  Future<void> onLoad() async {
    _painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: kGameFontFamily,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: strong ? GameColors.accent : GameColors.textPrimary,
          shadows: const [Shadow(blurRadius: 6, color: Color(0xAA000000))],
        ),
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
