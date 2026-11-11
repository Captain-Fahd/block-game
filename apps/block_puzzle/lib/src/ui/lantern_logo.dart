import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../game/glow.dart';

/// Code-drawn Lantern Blocks mark (ADR 008): a lantern whose light is a
/// 2x2 grid of glowing blocks, with a slow, gentle flicker. Also the basis
/// for the app icon (P7.5).
class LanternLogo extends StatefulWidget {
  const LanternLogo({super.key, this.size = 120, this.animate = true});

  /// Height in logical pixels; width is 0.8x.
  final double size;
  final bool animate;

  @override
  State<LanternLogo> createState() => _LanternLogoState();
}

class _LanternLogoState extends State<LanternLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        size: Size(widget.size * 0.8, widget.size),
        painter: LanternPainter(flicker: _flicker(_c.value)),
      ),
    ),
  );

  /// 0.85..1.0, two slow sines so it never looks like a metronome.
  static double _flicker(double v) {
    final t = v * 2 * math.pi;
    return 0.925 + 0.075 * math.sin(t * 3) * math.sin(t * 5 + 1);
  }
}

class LanternPainter extends CustomPainter {
  LanternPainter({this.flicker = 1});

  final double flicker;

  static const _bronze = Color(0xFFB8874A);
  static const _bronzeDark = Color(0xFF7A5630);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    // Body (glass) geometry.
    final body = Rect.fromLTWH(w * 0.18, h * 0.30, w * 0.64, h * 0.52);
    final bodyR = RRect.fromRectAndRadius(body, Radius.circular(w * 0.08));

    // Halo.
    final haloR = h * 0.62;
    canvas.drawCircle(
      body.center,
      haloR,
      Paint()
        ..shader = ui.Gradient.radial(
          body.center,
          haloR,
          [
            kLanternAmber.withValues(alpha: 0.38 * flicker),
            kLanternAmber.withValues(alpha: 0.10 * flicker),
            kLanternAmber.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );

    final stroke = Paint()
      ..color = _bronze
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    // Handle ring.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cx, h * 0.12),
        width: w * 0.34,
        height: h * 0.18,
      ),
      math.pi,
      math.pi,
      false,
      stroke,
    );

    // Cap.
    final cap = Path()
      ..moveTo(w * 0.30, h * 0.14)
      ..lineTo(w * 0.70, h * 0.14)
      ..lineTo(w * 0.88, h * 0.30)
      ..lineTo(w * 0.12, h * 0.30)
      ..close();
    canvas.drawPath(cap, Paint()..color = _bronzeDark);
    canvas.drawPath(cap, stroke..strokeWidth = w * 0.03);

    // Glass: warm fill.
    canvas.drawRRect(
      bodyR,
      Paint()..color = kLanternAmber.withValues(alpha: 0.18 * flicker),
    );

    // The light: a 2x2 grid of glowing blocks.
    final cells = [
      GameColors.blocks[0],
      GameColors.blocks[2],
      GameColors.blocks[5],
      GameColors.blocks[3],
    ];
    final gridSide = math.min(body.width, body.height) * 0.62;
    final gap = gridSide * 0.08;
    final cell = (gridSide - gap) / 2;
    final origin = body.center - Offset(gridSide / 2, gridSide / 2);
    for (var i = 0; i < 4; i++) {
      final r = Rect.fromLTWH(
        origin.dx + (i % 2) * (cell + gap),
        origin.dy + (i ~/ 2) * (cell + gap),
        cell,
        cell,
      );
      final c = Color.lerp(cells[i], const Color(0xFFFFFFFF), 0.12 * flicker)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(cell * 0.22)),
        Paint()..color = Color.lerp(c, const Color(0xFF000000), 0.3)!,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(r.left, r.top, r.right, r.bottom - cell * 0.14),
          Radius.circular(cell * 0.22),
        ),
        Paint()..color = c,
      );
    }

    // Frame bars and outline over the glass.
    final frame = Paint()
      ..color = _bronze
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035;
    canvas.drawRRect(bodyR, frame);
    canvas.drawLine(
      Offset(body.left + body.width * 0.08, body.top),
      Offset(body.left + body.width * 0.08, body.bottom),
      frame..strokeWidth = w * 0.02,
    );
    canvas.drawLine(
      Offset(body.right - body.width * 0.08, body.top),
      Offset(body.right - body.width * 0.08, body.bottom),
      frame,
    );

    // Base.
    final base = Path()
      ..moveTo(w * 0.12, h * 0.82)
      ..lineTo(w * 0.88, h * 0.82)
      ..lineTo(w * 0.74, h * 0.94)
      ..lineTo(w * 0.26, h * 0.94)
      ..close();
    canvas.drawPath(base, Paint()..color = _bronzeDark);
    canvas.drawPath(
      base,
      Paint()
        ..color = _bronze
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.03,
    );
  }

  @override
  bool shouldRepaint(LanternPainter old) => old.flicker != flicker;
}
