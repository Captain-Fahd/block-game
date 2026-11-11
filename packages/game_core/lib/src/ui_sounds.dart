import 'package:flutter/widgets.dart';

/// Menu / UI sounds, separate from each game's gameplay sounds.
enum UiSound {
  /// Soft tick for buttons and list rows.
  tap,

  /// Tiny blip for switches; the player passes `on` to pitch it.
  toggle,
}

typedef UiSoundPlayer = void Function(UiSound sound, {bool on});

/// Provides a UI sound player to the widget tree. Shared widgets (e.g.
/// [GameButton]) call [UiSounds.play]; with no [UiSounds] above them they
/// stay silent, so tests and games without UI sounds need nothing.
class UiSounds extends InheritedWidget {
  const UiSounds({super.key, required this.player, required super.child});

  final UiSoundPlayer player;

  static void play(BuildContext context, UiSound sound, {bool on = true}) =>
      context.getInheritedWidgetOfExactType<UiSounds>()?.player(sound, on: on);

  @override
  bool updateShouldNotify(UiSounds oldWidget) => player != oldWidget.player;
}
