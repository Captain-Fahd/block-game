import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import '../model/game_controller.dart';
import '../model/game_state.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// Working title until Omar picks a name (P2.0).
const String kAppTitle = 'Block Puzzle';

/// Classic (Continue / Play / New game), Daily, best score, Settings.
/// Back from here exits the app (default root-route behaviour).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {}); // scores, saves and streak may have changed
  }

  @override
  Widget build(BuildContext context) {
    final s = ServicesScope.of(context);
    final p = s.progress;
    final theme = Theme.of(context);
    final savedClassic = p.loadGame(GameMode.classic);
    final savedDaily = p.loadGame(GameMode.daily);
    final best = p.bestFor(GameMode.classic);
    final streak = p.dailyStreak;
    final todayBest = p.todayDailyBest;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: GameSpacing.sm,
              right: GameSpacing.sm,
              child: IconButton(
                key: const Key('settings'),
                tooltip: 'Settings',
                iconSize: 30,
                color: GameColors.textSecondary,
                icon: const Icon(Icons.settings_rounded),
                onPressed: () => _open(const SettingsScreen()),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(GameSpacing.xl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _Logo(),
                        const SizedBox(height: GameSpacing.md),
                        Text(
                          kAppTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.displayLarge?.copyWith(
                            fontSize: 44,
                          ),
                        ),
                        const SizedBox(height: GameSpacing.sm),
                        Text(
                          best > 0 ? 'Best $best' : ' ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: GameColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: GameSpacing.xl),
                        if (savedClassic != null) ...[
                          GameButton(
                            key: const Key('continue'),
                            label: 'Continue  ·  ${savedClassic.score}',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => _open(
                              GameScreen(
                                controller: GameController.fromState(
                                  savedClassic,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: GameSpacing.md),
                          GameButton(
                            key: const Key('newGame'),
                            label: 'New game',
                            style: GameButtonStyle.secondary,
                            onPressed: () =>
                                _open(GameScreen.newGame(s, GameMode.classic)),
                          ),
                        ] else
                          GameButton(
                            key: const Key('play'),
                            label: 'Play',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () =>
                                _open(GameScreen.newGame(s, GameMode.classic)),
                          ),
                        const SizedBox(height: GameSpacing.md),
                        GameButton(
                          key: const Key('daily'),
                          label: savedDaily != null
                              ? 'Continue daily'
                              : 'Daily challenge',
                          icon: Icons.calendar_today_rounded,
                          style: GameButtonStyle.secondary,
                          onPressed: () => _open(
                            savedDaily != null
                                ? GameScreen(
                                    controller: GameController.fromState(
                                      savedDaily,
                                    ),
                                  )
                                : GameScreen.newGame(s, GameMode.daily),
                          ),
                        ),
                        const SizedBox(height: GameSpacing.sm),
                        Text(
                          [
                            if (todayBest > 0) "Today's best $todayBest",
                            if (streak > 0)
                              'Streak $streak ${streak == 1 ? 'day' : 'days'}',
                          ].join('  ·  '),
                          style: const TextStyle(
                            color: GameColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small code-drawn mark: four blocks.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    Widget block(Color c) => Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(7),
        border: Border(
          bottom: BorderSide(
            color: Color.lerp(c, const Color(0xFF000000), 0.3)!,
            width: 4,
          ),
        ),
      ),
    );
    final b = GameColors.blocks;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [block(b[0]), block(b[2])],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [block(b[5]), block(b[3])],
        ),
      ],
    );
  }
}
