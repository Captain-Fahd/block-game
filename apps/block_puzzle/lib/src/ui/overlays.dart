import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import 'game_screen.dart';

/// Dimmed panel used by the in-game overlays.
class _Panel extends StatelessWidget {
  const _Panel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: GameColors.background.withValues(alpha: 0.85),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(GameSpacing.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    ),
  );
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.screen});

  static const id = 'pause';
  final GameScreenState screen;

  @override
  Widget build(BuildContext context) => _Panel(
    children: [
      Text('Paused', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: GameSpacing.xl),
      GameButton(
        label: 'Resume',
        icon: Icons.play_arrow_rounded,
        onPressed: screen.resume,
      ),
      const SizedBox(height: GameSpacing.md),
      GameButton(
        label: 'Restart',
        icon: Icons.refresh_rounded,
        style: GameButtonStyle.secondary,
        onPressed: screen.restart,
      ),
      const SizedBox(height: GameSpacing.md),
      GameButton(
        label: 'Home',
        icon: Icons.home_rounded,
        style: GameButtonStyle.secondary,
        onPressed: screen.quitToHome,
      ),
    ],
  );
}

/// "No moves left", with the rewarded second-chance offer when available.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.screen});

  static const id = 'gameOver';
  final GameScreenState screen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = screen.game.controller.state.score;
    return _Panel(
      children: [
        Text('No moves left', style: theme.textTheme.headlineMedium),
        const SizedBox(height: GameSpacing.sm),
        Text('$score', style: theme.textTheme.displayLarge),
        if (screen.offerSecondChance) ...[
          const SizedBox(height: GameSpacing.lg),
          const Text(
            'Watch a short ad for three pieces that fit?',
            textAlign: TextAlign.center,
            style: TextStyle(color: GameColors.textSecondary, fontSize: 16),
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'Second chance',
            icon: Icons.play_circle_fill_rounded,
            onPressed: screen.watchForSecondChance,
          ),
          const SizedBox(height: GameSpacing.md),
          GameButton(
            label: 'No thanks',
            style: GameButtonStyle.secondary,
            onPressed: screen.finish,
          ),
        ],
      ],
    );
  }
}
