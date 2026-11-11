import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/drag_gain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dragGain', () {
    test('1:1 at and below the start speed', () {
      expect(dragGain(0), kDragGainMin);
      expect(dragGain(kDragAccelStartSpeed), kDragGainMin);
    });

    test('max at and above the full speed', () {
      expect(dragGain(kDragAccelFullSpeed), closeTo(kDragGainMax, 1e-12));
      expect(dragGain(1000), closeTo(kDragGainMax, 1e-12));
    });

    test('halfway speed gives halfway gain (smoothstep midpoint)', () {
      const mid = (kDragAccelStartSpeed + kDragAccelFullSpeed) / 2;
      expect(dragGain(mid), closeTo((kDragGainMin + kDragGainMax) / 2, 1e-12));
    });

    test('never decreases as speed rises', () {
      var last = 0.0;
      for (var s = 0.0; s <= 30; s += 0.25) {
        final g = dragGain(s);
        expect(g, greaterThanOrEqualTo(last));
        last = g;
      }
    });
  });
}
