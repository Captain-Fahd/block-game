import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';

import '../../constants.dart';
import '../../model/piece.dart';
import '../block_game.dart';

/// One third of the tray. Owns the touch area (bigger than the small piece)
/// and forwards drags to the game.
class TraySlot extends PositionComponent
    with DragCallbacks, HasGameReference<BlockGame> {
  TraySlot(this.index);

  final int index;
  PieceView? view;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final r = game.layout.traySlot(index);
    position = Vector2(r.left, r.top);
    this.size = Vector2(r.width, r.height);
    view?.goHome(animate: false);
  }

  Vector2 get home => position + size / 2;

  void attach(PieceView v) {
    view = v..slot = this;
    v.goHome(animate: false);
  }

  /// Removes the slot's piece view (placed, or replaced by a new tray).
  void clear() {
    view?.removeFromParent();
    view = null;
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    game.startDrag(index, event.canvasPosition.toOffset());
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (game.drag?.slot == index) {
      game.moveDrag(event.canvasEndPosition.toOffset());
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (game.drag?.slot == index) game.endDrag();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    super.onDragCancel(event);
    if (game.drag?.slot == index) game.cancelDrag();
  }
}

/// A tray piece. Always laid out at board cell size and scaled down to
/// [kTrayCellScale] while resting in the tray, so lifting is a scale-up.
///
/// Animations are a single tween owned by this component rather than Flame
/// effects: a new animation (lift, return, deal) simply replaces the old
/// one, even if both are started in the same frame.
class PieceView extends PositionComponent with HasGameReference<BlockGame> {
  PieceView(this.piece) : super(anchor: Anchor.center, priority: 10);

  final Piece piece;
  TraySlot? slot;
  bool _lifted = false;
  _Tween? _tween;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _resize();
  }

  @override
  void onMount() {
    super.onMount();
    _resize();
  }

  void _resize() {
    final cell = game.dragCell;
    size = Vector2(piece.width * cell, piece.height * cell);
  }

  double get restScale => kTrayCellScale / kDragCellScale;
  bool get isLifted => _lifted;
  bool get isAnimating => _tween != null;

  void _animate({
    Vector2? to,
    required double scaleTo,
    required double duration,
    Curve curve = Curves.easeOut,
    double delay = 0,
    double? scaleFrom,
  }) {
    if (scaleFrom != null) scale = Vector2.all(scaleFrom);
    _tween = _Tween(
      fromPos: position.clone(),
      toPos: to?.clone(),
      fromScale: scale.x,
      toScale: scaleTo,
      duration: duration,
      delay: delay,
      curve: curve,
    );
  }

  void goHome({required bool animate}) {
    final s = slot;
    if (s == null) return;
    _lifted = false;
    priority = 10;
    if (!animate) {
      _tween = null;
      position = s.home;
      scale = Vector2.all(restScale);
      return;
    }
    _animate(to: s.home, scaleTo: restScale, duration: kReturnDuration);
  }

  void returnHome() => goHome(animate: true);

  /// Scales up to drag size; the game moves it with the finger.
  void lift() {
    _lifted = true;
    priority = 100;
    _animate(scaleTo: 1, duration: kLiftDuration);
  }

  /// Pops in from nothing when a new tray is dealt.
  void dealIn({double delay = 0}) => _animate(
    scaleFrom: 0,
    scaleTo: restScale,
    duration: kDealDuration,
    delay: delay,
    curve: Curves.easeOutBack,
  );

  @override
  void update(double dt) {
    super.update(dt);
    final t = _tween;
    if (t == null) return;
    t.elapsed += dt;
    final raw = ((t.elapsed - t.delay) / t.duration).clamp(0.0, 1.0);
    final k = t.curve.transform(raw);
    scale = Vector2.all(t.fromScale + (t.toScale - t.fromScale) * k);
    final to = t.toPos;
    if (to != null) position = t.fromPos + (to - t.fromPos) * k;
    if (raw >= 1) _tween = null;
  }

  @override
  void render(Canvas canvas) {
    final cell = game.dragCell;
    if (cell <= 0) return;
    final sprites = game.sprites;
    for (final c in piece.cells) {
      sprites.draw(
        canvas,
        piece.colourIndex,
        Rect.fromLTWH(c.col * cell, c.row * cell, cell, cell),
      );
    }
  }
}

class _Tween {
  _Tween({
    required this.fromPos,
    required this.toPos,
    required this.fromScale,
    required this.toScale,
    required this.duration,
    required this.delay,
    required this.curve,
  });

  final Vector2 fromPos;
  final Vector2? toPos;
  final double fromScale;
  final double toScale;
  final double duration;
  final double delay;
  final Curve curve;
  double elapsed = 0;
}
