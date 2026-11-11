import '../constants.dart';

/// Gain applied to finger movement while dragging, from the finger's speed
/// in cells per second: [kDragGainMin] up to [kDragAccelStartSpeed], easing
/// (smoothstep) to [kDragGainMax] at [kDragAccelFullSpeed] and above.
double dragGain(double speedCellsPerSecond) {
  const span = kDragAccelFullSpeed - kDragAccelStartSpeed;
  final t = ((speedCellsPerSecond - kDragAccelStartSpeed) / span).clamp(
    0.0,
    1.0,
  );
  final eased = t * t * (3 - 2 * t);
  return kDragGainMin + (kDragGainMax - kDragGainMin) * eased;
}
