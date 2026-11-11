import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

void main() {
  test('palettes have 8 colours and a pattern each', () {
    expect(GameColors.blocks.length, 8);
    expect(GameColors.blocksColourBlind.length, 8);
    expect(kBlockPatterns.length, 8);
  });

  testWidgets('GameButton taps, disables and GameDialog shows', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildGameTheme(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                GameButton(
                  label: 'Play',
                  icon: Icons.play_arrow,
                  onPressed: () => taps++,
                ),
                const GameButton(
                  label: 'Locked',
                  style: GameButtonStyle.secondary,
                  onPressed: null,
                ),
                GameButton(
                  label: 'Dialog',
                  style: GameButtonStyle.secondary,
                  expand: false,
                  onPressed: () => GameDialog.show<void>(
                    context,
                    title: 'Paused',
                    body: const Text('Take a breather'),
                    actions: [
                      GameButton(
                        label: 'Resume',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Play'));
    await tester.tap(find.text('Locked'));
    await tester.pumpAndSettle();
    expect(taps, 1);

    await tester.tap(find.text('Dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Take a breather'), findsOneWidget);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('GameButton plays a UI tap via UiSounds; silent without it', (
    tester,
  ) async {
    final played = <(UiSound, bool)>[];
    var taps = 0;
    Widget app({required bool withSounds}) {
      final body = Column(
        children: [
          GameButton(label: 'Go', onPressed: () => taps++),
          const GameButton(label: 'Off', onPressed: null),
        ],
      );
      return MaterialApp(
        home: Scaffold(
          body: withSounds
              ? UiSounds(
                  player: (s, {on = true}) => played.add((s, on)),
                  child: body,
                )
              : body,
        ),
      );
    }

    await tester.pumpWidget(app(withSounds: true));
    await tester.tap(find.text('Go'));
    await tester.tap(find.text('Off'));
    await tester.pump();
    expect(played, [(UiSound.tap, true)]);
    expect(taps, 1);

    await tester.pumpWidget(app(withSounds: false));
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(taps, 2, reason: 'still works with no UiSounds');
    expect(played, hasLength(1));
  });
}
