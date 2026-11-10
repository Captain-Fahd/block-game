import 'package:flame/components.dart';
import 'package:flame/effects.dart';
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
class PieceView extends PositionComponent with HasGameReference<BlockGame> {
  PieceView(this.piece) : super(anchor: Anchor.center, priority: 10);

  final Piece piece;
  TraySlot? slot;
  bool _lifted = false;

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

  void _stopEffects() => children.whereType<Effect>().toList().forEach(
    (e) => e.removeFromParent(),
  );

  void goHome({required bool animate}) {
    final s = slot;
    if (s == null) return;
    _stopEffects();
    _lifted = false;
    priority = 10;
    if (!animate) {
      position = s.home;
      scale = Vector2.all(restScale);
      return;
    }
    final c = EffectController(
      duration: kReturnDuration,
      curve: Curves.easeOut,
    );
    add(MoveEffect.to(s.home, c));
    add(
      ScaleEffect.to(
        Vector2.all(restScale),
        EffectController(duration: kReturnDuration, curve: Curves.easeOut),
      ),
    );
  }

  void returnHome() => goHome(animate: true);

  void lift() {
    _stopEffects();
    _lifted = true;
    priority = 100;
    add(
      ScaleEffect.to(
        Vector2.all(1),
        EffectController(duration: kLiftDuration, curve: Curves.easeOut),
      ),
    );
  }

  bool get isLifted => _lifted;

  /// Pops in from nothing when a new tray is dealt.
  void dealIn({double delay = 0}) {
    scale = Vector2.zero();
    add(
      ScaleEffect.to(
        Vector2.all(restScale),
        EffectController(
          duration: kDealDuration,
          startDelay: delay,
          curve: Curves.easeOutBack,
        ),
      ),
    );
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
