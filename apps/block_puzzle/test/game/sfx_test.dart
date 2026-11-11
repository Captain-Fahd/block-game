import 'dart:math' as math;

import 'package:block_puzzle/src/constants.dart';
import 'package:block_puzzle/src/game/sfx.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clear pitch steps up musical intervals and caps at the last', () {
    expect(clearRate(0), 1);
    expect(clearRate(1), closeTo(math.pow(2, 2 / 12), 1e-12));
    final top = math.pow(2, kClearStreakSemitones.last / 12);
    expect(clearRate(kClearStreakSemitones.length - 1), closeTo(top, 1e-12));
    expect(clearRate(50), closeTo(top, 1e-12));
    expect(clearRate(-1), 1);
    expect(top, lessThanOrEqualTo(1.5), reason: 'stays well below piercing');
  });

  test('every effect has a file', () {
    for (final s in Sfx.values) {
      expect(kSfxFiles[s], isNotNull, reason: '$s');
    }
  });
}
