/// Injected time source so time-based rules (ad caps, review prompts) can be
/// tested with a fake clock.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
