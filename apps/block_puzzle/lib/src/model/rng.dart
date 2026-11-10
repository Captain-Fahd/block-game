/// Small seeded PRNG whose whole state is one 32-bit int, so it can be saved
/// with the game and resumed exactly. (`dart:math` Random can't be serialised.)
///
/// Algorithm: xorshift32, seeded through a splitmix-style scramble so nearby
/// seeds (e.g. consecutive dates) give unrelated sequences.
class SeededRng {
  SeededRng(int seed) : _state = _scramble(seed);

  SeededRng.fromState(int state)
    : assert(state != 0, 'xorshift state must be non-zero'),
      _state = state & _mask;

  static const int _mask = 0xFFFFFFFF;

  int _state;
  int get state => _state;

  static int _scramble(int seed) {
    var z = (seed + 0x9E3779B9) & _mask;
    z = ((z ^ (z >> 16)) * 0x85EBCA6B) & _mask;
    z = ((z ^ (z >> 13)) * 0xC2B2AE35) & _mask;
    z = (z ^ (z >> 16)) & _mask;
    return z == 0 ? 0x6D2B79F5 : z;
  }

  /// Next raw 32-bit value.
  int nextUint32() {
    var x = _state;
    x ^= (x << 13) & _mask;
    x ^= x >> 17;
    x ^= (x << 5) & _mask;
    _state = x & _mask;
    return _state;
  }

  /// Uniform double in [0, 1).
  double nextDouble() => nextUint32() / 4294967296.0;

  /// Uniform int in [0, max).
  int nextInt(int max) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'must be positive');
    return (nextDouble() * max).floor();
  }
}
