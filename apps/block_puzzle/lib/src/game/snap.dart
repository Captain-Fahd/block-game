import 'dart:math' as math;

import '../constants.dart';

/// The closest position (top-left cell) within [tolerance] cells of the
/// fractional grid position ([row], [col]) where [fits] is true, or null.
///
/// Used when the nearest cell doesn't fit, so a piece held slightly off a
/// valid spot (over a neighbouring block, or a little past the board edge)
/// still lands there.
({int row, int col})? findSnap({
  required double row,
  required double col,
  required bool Function(int row, int col) fits,
  double tolerance = kSnapToleranceCells,
}) {
  ({int row, int col})? best;
  var bestDist = double.infinity;
  for (var r = (row - tolerance).ceil(); r <= (row + tolerance).floor(); r++) {
    for (
      var c = (col - tolerance).ceil();
      c <= (col + tolerance).floor();
      c++
    ) {
      final d = math.sqrt((r - row) * (r - row) + (c - col) * (c - col));
      if (d > tolerance || d >= bestDist) continue;
      if (!fits(r, c)) continue;
      best = (row: r, col: c);
      bestDist = d;
    }
  }
  return best;
}
