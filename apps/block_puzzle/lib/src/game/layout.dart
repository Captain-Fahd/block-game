import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'package:meta/meta.dart';

import '../constants.dart';

/// Where everything goes on screen. Pure maths, so it can be unit tested for
/// any screen size.
@immutable
class GameLayout {
  const GameLayout({
    required this.play,
    required this.hud,
    required this.board,
    required this.cell,
    required this.tray,
  });

  /// Computes the layout for a canvas of [size] with safe-area [insets].
  ///
  /// The play column is at most [kMaxPlayWidth] wide and centred, so tablets
  /// are letterboxed. The cell size is the largest that fits both the width
  /// and the height (HUD + board + gap + tray).
  factory GameLayout.compute(
    Size size, {
    EdgeInsets insets = EdgeInsets.zero,
    int boardSize = kBoardSize,
  }) {
    final safe = insets.deflateRect(Offset.zero & size);
    final playWidth = math.min(safe.width, kMaxPlayWidth);
    final play = Rect.fromLTWH(
      safe.left + (safe.width - playWidth) / 2,
      safe.top,
      playWidth,
      safe.height,
    );

    final gridCells = boardSize + 2 * kBoardPaddingCells;
    final byWidth = (play.width - 2 * kPlayMargin) / gridCells;
    final byHeight =
        (play.height - kHudHeight) /
        (gridCells + kTrayGapCells + kTrayHeightCells);
    final cell = math.max(0.0, math.min(byWidth, byHeight));

    // Centre the HUD + board + tray block vertically in the spare space.
    final boardSide = cell * gridCells;
    final contentHeight =
        kHudHeight + boardSide + cell * (kTrayGapCells + kTrayHeightCells);
    final top = play.top + math.max(0.0, (play.height - contentHeight) / 2);

    final hud = Rect.fromLTWH(play.left, top, play.width, kHudHeight);
    final board = Rect.fromLTWH(
      play.center.dx - boardSide / 2,
      hud.bottom,
      boardSide,
      boardSide,
    );
    final tray = Rect.fromLTWH(
      board.left,
      board.bottom + cell * kTrayGapCells,
      boardSide,
      cell * kTrayHeightCells,
    );
    return GameLayout(
      play: play,
      hud: hud,
      board: board,
      cell: cell,
      tray: tray,
    );
  }

  /// The letterboxed play column.
  final Rect play;
  final Rect hud;

  /// The board well, including its padding.
  final Rect board;

  /// Side of one board cell.
  final double cell;
  final Rect tray;

  /// Top-left of the 8x8 grid inside the well.
  Offset get gridOrigin => board.topLeft + Offset(padding, padding);
  double get padding => cell * kBoardPaddingCells;

  /// Rect of grid cell ([row], [col]).
  Rect cellRect(int row, int col) => Rect.fromLTWH(
    gridOrigin.dx + col * cell,
    gridOrigin.dy + row * cell,
    cell,
    cell,
  );

  /// One third of the tray per slot.
  Rect traySlot(int slot, {int slots = kTraySize}) {
    final w = tray.width / slots;
    return Rect.fromLTWH(tray.left + slot * w, tray.top, w, tray.height);
  }

  /// Where [topLeft] is on the grid, in (fractional) cells.
  ({double row, double col}) gridPosition(Offset topLeft) => (
    row: (topLeft.dy - gridOrigin.dy) / cell,
    col: (topLeft.dx - gridOrigin.dx) / cell,
  );

  /// The grid cell a piece would snap to if its top-left corner is at
  /// [topLeft], or null if it is more than [kSnapThresholdCells] from any
  /// cell. Row/col may be out of range; the board decides if it fits.
  ({int row, int col})? snapCell(Offset topLeft) {
    if (cell <= 0) return null;
    final fx = (topLeft.dx - gridOrigin.dx) / cell;
    final fy = (topLeft.dy - gridOrigin.dy) / cell;
    final col = fx.round();
    final row = fy.round();
    if ((fx - col).abs() > kSnapThresholdCells ||
        (fy - row).abs() > kSnapThresholdCells) {
      return null;
    }
    return (row: row, col: col);
  }
}
