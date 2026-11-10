import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';
import 'package:game_core/game_core.dart';

import '../block_game.dart';

/// The board well, empty cells, placed blocks and the drag ghost.
class BoardComponent extends PositionComponent
    with HasGameReference<BlockGame> {
  ui.Picture? _well;
  double _wellCell = -1;

  static final Paint _invalid = Paint()
    ..color = GameColors.danger.withValues(alpha: 0.45);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final b = game.layout.board;
    position = Vector2(b.left, b.top);
    this.size = Vector2(b.width, b.height);
  }

  /// The well and empty-cell grid never change during a game, so they are
  /// recorded once per cell size and replayed each frame.
  ui.Picture _wellPicture() {
    final l = game.layout;
    if (_well != null && _wellCell == l.cell) return _well!;
    _well?.dispose();
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    final outer = Offset.zero & l.board.size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.circular(l.cell * 0.3)),
      Paint()..color = GameColors.boardWell,
    );
    final empty = Paint()..color = GameColors.gridLine.withValues(alpha: 0.55);
    final n = game.controller.state.board.size;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final rect = _local(r, c).deflate(l.cell * 0.05);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(l.cell * 0.16)),
          empty,
        );
      }
    }
    _wellCell = l.cell;
    return _well = rec.endRecording();
  }

  Rect _local(int row, int col) =>
      game.layout.cellRect(row, col).shift(-game.layout.board.topLeft);

  @override
  void render(Canvas canvas) {
    if (game.layout.cell <= 0) return;
    canvas.drawPicture(_wellPicture());

    final board = game.controller.state.board;
    final sprites = game.sprites;
    for (var r = 0; r < board.size; r++) {
      for (var c = 0; c < board.size; c++) {
        final v = board.at(r, c);
        if (v >= 0) sprites.draw(canvas, v, _local(r, c));
      }
    }

    final g = game.ghost;
    if (g == null) return;
    for (final cell in g.piece.cells) {
      final r = g.row + cell.row;
      final c = g.col + cell.col;
      if (r < 0 || c < 0 || r >= board.size || c >= board.size) continue;
      final rect = _local(r, c);
      if (g.valid) {
        sprites.draw(canvas, g.piece.colourIndex, rect, opacity: 0.4);
      } else if (!board.isFilled(r, c)) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(game.layout.cell * 0.05),
            Radius.circular(game.layout.cell * 0.16),
          ),
          _invalid,
        );
      }
    }
  }

  @override
  void onRemove() {
    _well?.dispose();
    _well = null;
    super.onRemove();
  }
}
