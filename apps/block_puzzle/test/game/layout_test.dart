import 'package:flutter/painting.dart';

import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameLayout', () {
    test('small phone (360x640): board fits the width with margins', () {
      final l = GameLayout.compute(const Size(360, 640));
      expect(l.board.left, greaterThanOrEqualTo(kPlayMargin - 0.001));
      expect(l.board.right, lessThanOrEqualTo(360 - kPlayMargin + 0.001));
      expect(l.tray.bottom, lessThanOrEqualTo(640 + 0.001));
      expect(l.cell, greaterThan(30));
    });

    test('tall phone: limited by width, content centred vertically', () {
      final l = GameLayout.compute(const Size(412, 915));
      final gap = l.hud.top - l.play.top;
      expect(gap, greaterThan(0));
      expect(915 - l.tray.bottom, closeTo(gap, 0.001));
    });

    test('short wide screen: limited by height', () {
      final l = GameLayout.compute(const Size(800, 500));
      expect(l.hud.top, closeTo(0, 0.001));
      expect(l.tray.bottom, closeTo(500, 0.001));
      expect(l.board.width, lessThan(800 - 2 * kPlayMargin));
    });

    test('tablet is letterboxed and centred', () {
      final l = GameLayout.compute(const Size(1024, 1366));
      expect(l.play.width, kMaxPlayWidth);
      expect(l.play.center.dx, closeTo(512, 0.001));
      expect(l.board.center.dx, closeTo(512, 0.001));
    });

    test('safe-area insets are respected', () {
      const insets = EdgeInsets.only(top: 40, bottom: 30);
      final l = GameLayout.compute(const Size(360, 640), insets: insets);
      expect(l.hud.top, greaterThanOrEqualTo(40));
      expect(l.tray.bottom, lessThanOrEqualTo(610 + 0.001));
    });

    test('zero size gives a zero cell rather than a negative one', () {
      final l = GameLayout.compute(Size.zero);
      expect(l.cell, 0);
      expect(l.snapCell(Offset.zero), isNull);
    });

    test('cell rects tile the grid', () {
      final l = GameLayout.compute(const Size(360, 640));
      expect(l.cellRect(0, 0).topLeft, l.gridOrigin);
      expect(l.cellRect(7, 7).right, closeTo(l.board.right - l.padding, 1e-6));
      expect(l.cellRect(0, 1).left, closeTo(l.cellRect(0, 0).right, 1e-9));
    });

    test('tray slots split the tray in three', () {
      final l = GameLayout.compute(const Size(360, 640));
      expect(l.traySlot(0).left, l.tray.left);
      expect(l.traySlot(2).right, closeTo(l.tray.right, 1e-9));
    });

    test('snap: nearest cell within half a cell, else null', () {
      final l = GameLayout.compute(const Size(360, 640));
      final o = l.cellRect(2, 3).topLeft;
      final c = l.cell;
      expect(l.snapCell(o), (row: 2, col: 3));
      expect(l.snapCell(o + Offset(0.4 * c, -0.4 * c)), (row: 2, col: 3));
      expect(l.snapCell(o + Offset(0.6 * c, 0)), (row: 2, col: 4));
      // Off the board: still a cell index; the board rejects it.
      expect(l.snapCell(l.gridOrigin - Offset(c, 0)), (row: 0, col: -1));
    });
  });
}
