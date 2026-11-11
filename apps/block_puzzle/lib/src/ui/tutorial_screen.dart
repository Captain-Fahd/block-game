import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import '../game/block_game.dart';
import '../model/board.dart';
import '../model/game_controller.dart';
import '../model/game_state.dart';
import '../model/piece.dart';
import '../model/pieces.dart';
import '../model/rng.dart';
import '../model/scoring.dart';

/// One scripted tutorial step on a preset board.
class TutorialStep {
  const TutorialStep({
    required this.text,
    required this.board,
    required this.piece,
    this.hints = const {},
    this.needsClear = false,
  });

  final String text;
  final List<String> board;
  final String piece;
  final Set<CellOffset> hints;

  /// The step only counts if the placement clears a line.
  final bool needsClear;
}

const _empty = '........';

final List<TutorialStep> kTutorialSteps = [
  const TutorialStep(
    text: 'Drag the block onto the board.',
    board: [_empty, _empty, _empty, _empty, _empty, _empty, _empty, _empty],
    piece: 'O',
  ),
  const TutorialStep(
    text: 'Fill a whole row to clear it.',
    board: [_empty, _empty, _empty, _empty, _empty, _empty, _empty, '...12345'],
    piece: 'I3_h',
    hints: {(row: 7, col: 0), (row: 7, col: 1), (row: 7, col: 2)},
    needsClear: true,
  ),
  const TutorialStep(
    text: 'Columns clear too. Fill this one.',
    board: [
      '.......6',
      '.......6',
      '.......6',
      '.......6',
      '.......6',
      _empty,
      _empty,
      _empty,
    ],
    piece: 'I3_v',
    hints: {(row: 5, col: 7), (row: 6, col: 7), (row: 7, col: 7)},
    needsClear: true,
  ),
];

/// First-launch tutorial (also reachable from Settings). Skippable. Marks
/// the tutorial done and logs `tutorial_complete` when finished or skipped.
/// No ads here.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<TutorialScreen> createState() => TutorialScreenState();
}

class TutorialScreenState extends State<TutorialScreen> {
  late final AppServices _s = ServicesScope.of(context);
  BlockGame? _game;
  int step = 0;
  bool finished = false;
  bool _retry = false;
  bool _advancing = false;

  BlockGame get game => _game!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _game ??= BlockGame(
      controller: _controllerFor(kTutorialSteps[0]),
      audio: _s.audio,
      haptics: _s.haptics,
      colourBlind: _s.settings.colourBlindPatterns,
      hiddenSlots: const {1, 2},
      showHud: false,
      onPlacement: _onPlacement,
    )..hintCells = kTutorialSteps[0].hints;
  }

  static GameController _controllerFor(TutorialStep t) =>
      GameController.fromState(
        GameState(
          mode: GameMode.classic,
          seed: 1,
          board: Board.fromRows(t.board),
          // Slots 1 and 2 hold hidden monos so the tray never refills.
          tray: [pieceById(t.piece), pieceById('mono'), pieceById('mono')],
          score: 0,
          streak: kInitialStreak,
          rngState: SeededRng(1).state,
        ),
      );

  void _onPlacement(PlacementResult r) {
    final t = kTutorialSteps[step];
    final ok = !t.needsClear || r.linesCleared > 0;
    _advancing = true;
    // Let the placement / clear animation play before moving on.
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        _advancing = false;
        if (!ok) {
          setState(() => _retry = true);
          _load(step);
        } else if (step + 1 < kTutorialSteps.length) {
          setState(() {
            _retry = false;
            step++;
          });
          _load(step);
        } else {
          game.hintCells = const {};
          setState(() => finished = true);
        }
      }),
    );
  }

  void _load(int i) {
    final t = kTutorialSteps[i];
    game.startGame(_controllerFor(t), hiddenSlots: const {1, 2});
    game.hintCells = t.hints;
  }

  Future<void> complete({required bool skipped}) async {
    await _s.progress.setTutorialDone();
    _s.analytics.logEvent(AnalyticsEvents.tutorialComplete, {
      'skipped': skipped ? 1 : 0,
      'step': step,
    });
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = finished
        ? "That's it! Place blocks, clear lines and keep going as long as you can."
        : _retry
        ? 'Almost! Fill the highlighted cells.'
        : kTutorialSteps[step].text;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            GameWidget<BlockGame>(game: game),
            Positioned(
              top: GameSpacing.sm,
              right: GameSpacing.sm,
              child: TextButton(
                key: const Key('skipTutorial'),
                onPressed: () => complete(skipped: true),
                child: const Text('Skip'),
              ),
            ),
            Positioned(
              top: GameSpacing.xl + GameSpacing.md,
              left: GameSpacing.lg,
              right: GameSpacing.lg,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      finished
                          ? ' '
                          : 'Step ${step + 1} of ${kTutorialSteps.length}',
                      style: const TextStyle(color: GameColors.textSecondary),
                    ),
                    const SizedBox(height: GameSpacing.xs),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        text,
                        key: ValueKey(text),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (finished)
              Positioned(
                left: GameSpacing.xl,
                right: GameSpacing.xl,
                bottom: GameSpacing.xl,
                child: GameButton(
                  key: const Key('tutorialPlay'),
                  label: "Let's play",
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => complete(skipped: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// For tests: whether a step transition is pending.
  bool get advancing => _advancing;
}
