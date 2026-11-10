import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:game_core/game_core.dart';

import '../constants.dart';

/// Draws one block into [rect]: a rounded square with a darker bottom edge,
/// a soft top highlight and, in colour-blind mode, a pattern overlay.
void paintBlock(
  Canvas canvas,
  Rect rect,
  Color colour, {
  BlockPattern pattern = BlockPattern.none,
}) {
  final s = rect.width;
  final r = Radius.circular(s * 0.2);
  // Blend towards black/white rather than shifting HSL lightness, which
  // over-saturates violets and reds.
  final dark = Color.lerp(colour, const Color(0xFF000000), 0.3)!;
  final light = Color.lerp(colour, const Color(0xFFFFFFFF), 0.45)!;

  // Darker bottom edge, then the face sitting on top of it.
  canvas.drawRRect(RRect.fromRectAndRadius(rect, r), Paint()..color = dark);
  final face = Rect.fromLTRB(
    rect.left,
    rect.top,
    rect.right,
    rect.bottom - s * 0.12,
  );
  canvas.drawRRect(RRect.fromRectAndRadius(face, r), Paint()..color = colour);

  // Top highlight band.
  final hi = Rect.fromLTWH(
    rect.left + s * 0.12,
    rect.top + s * 0.08,
    s * 0.76,
    s * 0.2,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(hi, Radius.circular(s * 0.1)),
    Paint()..color = light.withValues(alpha: 0.55),
  );

  if (pattern != BlockPattern.none) {
    _paintPattern(canvas, face.deflate(s * 0.18), pattern, dark);
  }
}

void _paintPattern(Canvas canvas, Rect r, BlockPattern pattern, Color colour) {
  final s = r.width;
  final stroke = Paint()
    ..color = colour.withValues(alpha: 0.85)
    ..style = PaintingStyle.stroke
    ..strokeWidth = s * 0.14
    ..strokeCap = StrokeCap.round;
  final fill = Paint()..color = colour.withValues(alpha: 0.85);
  final c = r.center;
  switch (pattern) {
    case BlockPattern.none:
      break;
    case BlockPattern.dot:
      canvas.drawCircle(c, s * 0.2, fill);
    case BlockPattern.ring:
      canvas.drawCircle(c, s * 0.3, stroke);
    case BlockPattern.stripeH:
      canvas.drawLine(r.centerLeft, r.centerRight, stroke);
    case BlockPattern.stripeV:
      canvas.drawLine(r.topCenter, r.bottomCenter, stroke);
    case BlockPattern.diagonal:
      canvas.drawLine(r.bottomLeft, r.topRight, stroke);
    case BlockPattern.cross:
      canvas
        ..drawLine(r.topLeft, r.bottomRight, stroke)
        ..drawLine(r.bottomLeft, r.topRight, stroke);
    case BlockPattern.square:
      canvas.drawRect(
        Rect.fromCenter(center: c, width: s * 0.55, height: s * 0.55),
        stroke,
      );
  }
}

/// Pre-rendered block images, one per colour, at a given cell size. Drawing
/// a cached image is much cheaper than re-drawing rounded rects every frame.
class BlockSprites {
  BlockSprites._(
    this.cellSize,
    this.pixelRatio,
    this.colourBlind,
    this._images,
  );

  /// Renders all colours now (synchronously), so nothing is drawn for the
  /// first time mid-game.
  factory BlockSprites.render({
    required double cellSize,
    required double pixelRatio,
    required bool colourBlind,
  }) {
    final colours = colourBlind
        ? GameColors.blocksColourBlind
        : GameColors.blocks;
    final px = (cellSize * pixelRatio).ceil().clamp(1, 1024);
    final images = <ui.Image>[];
    for (var i = 0; i < kColourCount; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final side = px.toDouble();
      final inset = side * kBlockGapFraction / 2;
      paintBlock(
        canvas,
        Rect.fromLTWH(inset, inset, side - 2 * inset, side - 2 * inset),
        colours[i % colours.length],
        pattern: colourBlind
            ? kBlockPatterns[i % kBlockPatterns.length]
            : BlockPattern.none,
      );
      final picture = recorder.endRecording();
      images.add(picture.toImageSync(px, px));
      picture.dispose();
    }
    return BlockSprites._(cellSize, pixelRatio, colourBlind, images);
  }

  final double cellSize;
  final double pixelRatio;
  final bool colourBlind;
  final List<ui.Image> _images;

  static final Paint _paint = Paint()..filterQuality = FilterQuality.medium;
  static final Paint _alphaPaint = Paint()
    ..filterQuality = FilterQuality.medium;

  bool matches(double cell, double ratio, bool cb) =>
      cell == cellSize && ratio == pixelRatio && cb == colourBlind;

  ui.Image image(int colourIndex) => _images[colourIndex % _images.length];

  /// Draws the block for [colourIndex] into [dst] (any size; scaled).
  void draw(Canvas canvas, int colourIndex, Rect dst, {double opacity = 1}) {
    final img = image(colourIndex);
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    if (opacity >= 1) {
      canvas.drawImageRect(img, src, dst, _paint);
    } else {
      _alphaPaint.color = Color.fromRGBO(255, 255, 255, opacity.clamp(0, 1));
      canvas.drawImageRect(img, src, dst, _alphaPaint);
    }
  }

  void dispose() {
    for (final i in _images) {
      i.dispose();
    }
  }
}
