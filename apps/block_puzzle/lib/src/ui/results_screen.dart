import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import '../data/progress_store.dart';
import '../model/game_state.dart';
import 'game_screen.dart';

/// Score, best, and "Play again" / "Home". (Phase 6 adds the capped
/// interstitial on both buttons; [gameDuration] and [rewardedWatched] are
/// kept for that.)
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({
    super.key,
    required this.mode,
    required this.record,
    required this.gameDuration,
    required this.rewardedWatched,
  });

  final GameMode mode;
  final GameEndRecord record;
  final Duration gameDuration;
  final bool rewardedWatched;

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final theme = Theme.of(context);
    final daily = mode == GameMode.daily;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(GameSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    daily ? 'Daily challenge' : 'Game over',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: GameSpacing.lg),
                  if (record.newBest)
                    const _Badge('New best!')
                  else
                    const SizedBox(height: 32),
                  Text('${record.score}', style: theme.textTheme.displayLarge),
                  const SizedBox(height: GameSpacing.sm),
                  Text(
                    'Best ${record.best}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: GameColors.textSecondary,
                    ),
                  ),
                  if (daily) ...[
                    const SizedBox(height: GameSpacing.sm),
                    Text(
                      record.dailyStreak == 1
                          ? 'Daily streak: 1 day'
                          : 'Daily streak: ${record.dailyStreak} days',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: GameColors.accent,
                      ),
                    ),
                  ],
                  const SizedBox(height: GameSpacing.xl),
                  GameButton(
                    label: 'Play again',
                    icon: Icons.replay_rounded,
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen.newGame(s, mode),
                      ),
                    ),
                  ),
                  const SizedBox(height: GameSpacing.md),
                  GameButton(
                    label: 'Home',
                    icon: Icons.home_rounded,
                    style: GameButtonStyle.secondary,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.symmetric(horizontal: GameSpacing.md),
    decoration: BoxDecoration(
      color: GameColors.accent,
      borderRadius: BorderRadius.circular(16),
    ),
    alignment: Alignment.center,
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: kGameFontFamily,
        fontWeight: FontWeight.w900,
        color: GameColors.onAccent,
      ),
    ),
  );
}
