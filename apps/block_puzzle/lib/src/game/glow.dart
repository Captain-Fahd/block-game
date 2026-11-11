import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Warm lantern light used for the glows, motes and embers (ADR 008).
const Color kLanternAmber = Color(0xFFFFC970);

/// A soft round light (white, radial falloff) rendered once to an image,
/// then drawn tinted and scaled. Much cheaper per frame than a blur.
class GlowSprite {
  GlowSprite._(this.image);

  factory GlowSprite.render({int size = 64}) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;
    canvas.drawCircle(
      Offset(r, r),
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(r, r),
          r,
          const [Color(0xFFFFFFFF), Color(0x66FFFFFF), Color(0x00FFFFFF)],
          const [0, 0.35, 1],
        ),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return GlowSprite._(image);
  }

  final ui.Image image;
  final Paint _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Draws the light centred on [centre] with diameter [size], tinted
  /// [colour] (its alpha is the light's strength).
  void draw(Canvas canvas, Offset centre, double size, Color colour) {
    _paint.colorFilter = ColorFilter.mode(colour, BlendMode.modulate);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCenter(center: centre, width: size, height: size),
      _paint,
    );
  }

  void dispose() => image.dispose();
}
