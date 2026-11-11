import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:game_core/game_core.dart';

import '../constants.dart';
import '../model/board.dart';
import '../model/game_controller.dart';
import '../model/piece.dart';
import 'block_sprites.dart';
import 'components/board_component.dart';
import 'components/effects.dart';
import 'components/hud_component.dart';
import 'components/tray.dart';
import 'drag_gain.dart';
import 'layout.dart';
import 'sfx.dart';

/// Where a dragged piece would land.
typedef Ghost = ({Piece piece, int row, int col, bool valid});

/// The piece currently being dragged.
class DragState {
  DragState(this.slot, this.view, this.finger, this.topLeft, this.time);
  final int slot;
  final PieceView view;

  /// Last finger position.
  Offset finger;

  /// The piece's top-left. With acceleration it moves by the finger's
  /// movement times [dragGain], so it can lead the finger.
  Offset topLeft;

  /// Game time of the last move, and smoothed finger speed (cells/s).
  double time;
  double speed = 0;
}

/// Hosts the board, tray and HUD and turns drags into model placements.
///
/// Rules live in [GameController]; this class only renders, animates and
/// forwards input. Drag handling is public ([startDrag], [moveDrag],
/// [endDrag]) so tests can drive it without gestures.
class BlockGame extends FlameGame {
  BlockGame({
    required this._controller,
    this.audio,
    this.haptics,
    ValueListenable<bool>? colourBlind,
    this.best = 0,
    this.onGameOver,
    this._pixelRatio,
  }) : colourBlind = colourBlind ?? ValueNotifier(false);

  GameController _controller;
  final AudioService<Sfx>? audio;
  final Haptics? haptics;
  final ValueListenable<bool> colourBlind;

  /// Best score before this game; passing it fires the new-best feedback.
  int best;

  /// Called (after a short delay for the last animation) when no tray piece
  /// fits.
  final void Function(BlockGame game)? onGameOver;
  final double? _pixelRatio;

  /// Speed-based drag acceleration (see [dragGain]). Autoplay turns it off
  /// so its finger paths land exactly.
  bool dragAcceleration = true;

  /// Game clock, for finger speed.
  double _time = 0;

  GameController get controller => _controller;
  GameLayout layout = GameLayout.compute(Size.zero);
  BlockSprites? _sprites;
  BlockSprites get sprites => _sprites!;

  late final PlayArea play;
  late final BoardComponent board;
  late final HudComponent hud;
  late final List<TraySlot> slots;

  DragState? _drag;
  DragState? get drag => _drag;
  Ghost? ghost;
  bool _newBestFired = false;
  double? _gameOverIn;

  double get pixelRatio =>
      _pixelRatio ??
      WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;

  @override
  Color backgroundColor() => GameColors.background;

  @override
  Future<void> onLoad() async {
    colourBlind.addListener(_onColourBlind);
    board = BoardComponent();
    hud = HudComponent();
    slots = [for (var i = 0; i < kTraySize; i++) TraySlot(i)];
    play = PlayArea()..addAll([board, hud, ...slots]);
    add(play);
    _ensureSprites();
    _syncTray(animate: false);
    add(Prewarm());
  }

  @override
  void onGameResize(Vector2 size) {
    // Lay out before children get their own onGameResize.
    layout = GameLayout.compute(size.toSize());
    _ensureSprites();
    super.onGameResize(size);
  }

  @override
  void onRemove() {
    colourBlind.removeListener(_onColourBlind);
    _sprites?.dispose();
    super.onRemove();
  }

  void _onColourBlind() => _ensureSprites();

  void _ensureSprites() {
    if (layout.cell <= 0) return;
    final s = _sprites;
    if (s != null && s.matches(layout.cell, pixelRatio, colourBlind.value)) {
      return;
    }
    _sprites = BlockSprites.render(
      cellSize: layout.cell,
      pixelRatio: pixelRatio,
      colourBlind: colourBlind.value,
    );
    s?.dispose();
  }

  // --- New game / resume -------------------------------------------------

  /// Replaces the running game (Play again, resume, second chance).
  void startGame(GameController controller, {int? best}) {
    _controller = controller;
    if (best != null) this.best = best;
    _newBestFired = false;
    _gameOverIn = null;
    _drag?.view.removeFromParent();
    _drag = null;
    ghost = null;
    play.children.whereType<TransientEffect>().forEach(
      (e) => e.removeFromParent(),
    );
    for (final s in slots) {
      s.clear();
    }
    _syncTray(animate: true);
    hud.refresh(animate: false);
  }

  /// Re-reads the tray from the controller (e.g. after a second chance).
  void refreshTray() => _syncTray(animate: true);

  void _syncTray({required bool animate}) {
    final tray = _controller.state.tray;
    for (var i = 0; i < slots.length; i++) {
      final piece = tray[i];
      final slot = slots[i];
      if (slot.view?.piece.id == piece?.id && piece != null) continue;
      slot.clear();
      if (piece != null) {
        final view = PieceView(piece);
        slot.attach(view);
        play.add(view);
        if (animate) view.dealIn(delay: i * 0.05);
      }
    }
  }

  // --- Dragging ----------------------------------------------------------

  /// Size of a dragged piece's cell.
  double get dragCell => layout.cell * kDragCellScale;

  /// Top-left of a dragged [piece] held by a finger at [finger].
  Offset pieceTopLeft(Piece piece, Offset finger) {
    final w = piece.width * dragCell;
    final h = piece.height * dragCell;
    return Offset(
      finger.dx - w / 2,
      finger.dy - kDragFingerOffsetCells * layout.cell - h,
    );
  }

  bool startDrag(int slot, Offset finger) {
    if (_drag != null || _controller.isOver) return false;
    final view = slots[slot].view;
    if (view == null) return false;
    final d = _drag = DragState(
      slot,
      view,
      finger,
      pieceTopLeft(view.piece, finger),
      _time,
    );
    view.lift();
    _moveView(d);
    return true;
  }

  void moveDrag(Offset finger) {
    final d = _drag;
    if (d == null) return;
    final delta = finger - d.finger;
    d.finger = finger;
    if (!dragAcceleration) {
      d.topLeft = pieceTopLeft(d.view.piece, finger);
    } else {
      final dt = _time - d.time;
      if (dt > 0 && layout.cell > 0) {
        // Several events can arrive in one frame (dt == 0); those reuse
        // the current speed estimate.
        final instant = delta.distance / layout.cell / dt;
        d.speed += (instant - d.speed) * kDragSpeedSmoothing;
        d.time = _time;
      }
      d.topLeft += delta * dragGain(d.speed);
    }
    _moveView(d);
  }

  /// Keeps a dragged piece fully on screen.
  Offset _clampToScreen(Piece piece, Offset tl) {
    final w = piece.width * dragCell;
    final h = piece.height * dragCell;
    return Offset(
      tl.dx.clamp(0.0, math.max(0.0, size.x - w)),
      tl.dy.clamp(0.0, math.max(0.0, size.y - h)),
    );
  }

  void _moveView(DragState d) {
    final piece = d.view.piece;
    final tl = d.topLeft = _clampToScreen(piece, d.topLeft);
    d.view.position = Vector2(
      tl.dx + piece.width * dragCell / 2,
      tl.dy + piece.height * dragCell / 2,
    );
    final snap = layout.snapCell(tl);
    if (snap == null || !_overlapsBoard(piece, snap.row, snap.col)) {
      ghost = null;
    } else {
      ghost = (
        piece: piece,
        row: snap.row,
        col: snap.col,
        valid: _controller.canPlace(d.slot, snap.row, snap.col),
      );
    }
  }

  bool _overlapsBoard(Piece p, int row, int col) {
    final n = _controller.state.board.size;
    return row < n && col < n && row + p.height > 0 && col + p.width > 0;
  }

  /// Drops the dragged piece: places it if the ghost is valid, otherwise
  /// sends it back to the tray. Returns the placement, if any.
  PlacementResult? endDrag() {
    final d = _drag;
    if (d == null) return null;
    _drag = null;
    final g = ghost;
    ghost = null;
    if (g == null || !g.valid) {
      if (g != null) audio?.play(Sfx.invalid);
      d.view.returnHome();
      return null;
    }
    return _place(d, g.row, g.col);
  }

  void cancelDrag() {
    final d = _drag;
    if (d == null) return;
    _drag = null;
    ghost = null;
    d.view.returnHome();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    final t = _gameOverIn;
    if (t != null) {
      _gameOverIn = t - dt;
      if (_gameOverIn! <= 0) {
        _gameOverIn = null;
        onGameOver?.call(this);
      }
    }
  }

  // --- Placement ---------------------------------------------------------

  PlacementResult _place(DragState d, int row, int col) {
    final before = _controller.state.board;
    final streakBefore = _controller.state.streak.streak;
    final result = _controller.place(d.slot, row, col);
    slots[d.slot].clear();

    final placed = before.place(result.piece, row, col);
    _feedback(result, streakBefore);
    _spawnEffects(result, placed);
    hud.refresh(
      animate: true,
      streakUp: result.score.streakAfter.streak > streakBefore,
    );
    if (result.trayRefilled) _syncTray(animate: true);

    if (result.gameOver) {
      audio?.play(Sfx.gameOver);
      _gameOverIn = kGameOverDelay;
    }
    return result;
  }

  void _feedback(PlacementResult r, int streakBefore) {
    if (r.linesCleared > 0) {
      final rate = math.min(kClearPitchMax, 1 + streakBefore * kClearPitchStep);
      audio?.play(Sfx.clear, rate: rate);
      haptics?.play(HapticPattern.medium);
    } else {
      audio?.play(Sfx.place);
      haptics?.play(HapticPattern.light);
    }
    if (!_newBestFired && best > 0 && _controller.state.score > best) {
      _newBestFired = true;
      audio?.play(Sfx.newBest);
      haptics?.play(HapticPattern.success);
      hud.celebrateBest();
    }
  }

  void _spawnEffects(PlacementResult r, Board placed) {
    if (r.clearedCells.isEmpty) {
      play.add(
        FloatingText(
          '+${r.score.total}',
          _pieceCentre(r),
          fontSize: layout.cell * 0.5,
        ),
      );
      return;
    }
    for (final c in r.clearedCells) {
      play.add(
        ClearingBlock(
          colourIndex: placed.at(c.row, c.col),
          rect: layout.cellRect(c.row, c.col),
          delay: _clearDelay(r, c),
        ),
      );
    }
    final text = r.score.multiplier > 1
        ? '+${r.score.total}  x${r.score.multiplier}'
        : '+${r.score.total}';
    play.add(
      FloatingText(
        text,
        _pieceCentre(r),
        fontSize: layout.cell * 0.7,
        strong: true,
      ),
    );
    if (r.boardCleared) {
      play.add(
        FloatingText(
          'Board clear!',
          layout.board.center,
          fontSize: layout.cell * 0.9,
          strong: true,
        ),
      );
    }
    if (r.linesCleared >= kShakeMinLines) {
      play.shake(kShakeAmplitudeCells * layout.cell);
    }
  }

  /// Cells sweep outwards from the placed piece, a few ms per cell.
  double _clearDelay(PlacementResult r, CellOffset c) {
    final pr = r.row + r.piece.height / 2;
    final pc = r.col + r.piece.width / 2;
    final d = math.max((c.row + 0.5 - pr).abs(), (c.col + 0.5 - pc).abs());
    return d * 0.018;
  }

  Offset _pieceCentre(PlacementResult r) {
    final tl = layout.cellRect(r.row, r.col).topLeft;
    return tl +
        Offset(
          r.piece.width * layout.cell / 2,
          r.piece.height * layout.cell / 2,
        );
  }
}

/// Container for everything on the play field, so a screen shake moves it
/// all together.
class PlayArea extends PositionComponent {
  double _shakeLeft = 0;
  double _amplitude = 0;
  final _rand = math.Random();

  bool get isShaking => _shakeLeft > 0;

  void shake(double amplitude) {
    _amplitude = amplitude;
    _shakeLeft = kShakeDuration;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_shakeLeft <= 0) return;
    _shakeLeft -= dt;
    if (_shakeLeft <= 0) {
      position.setZero();
      return;
    }
    final a = _amplitude * (_shakeLeft / kShakeDuration);
    position.setValues(
      (_rand.nextDouble() * 2 - 1) * a,
      (_rand.nextDouble() * 2 - 1) * a,
    );
  }
}
