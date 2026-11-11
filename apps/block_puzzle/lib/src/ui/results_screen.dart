import 'dart:async';

import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import '../data/progress_store.dart';
import '../model/game_state.dart';
import 'game_screen.dart';

/// Score, best, and "Play again" / "Home".
///
/// - A new best may trigger the store review prompt (P6.6; the prompter
///   decides: never in the first session, at most once per 30 days).
/// - Leaving via either button tries a capped interstitial first (P6.3),
///   unless a rewarded ad was watched or the review prompt was shown in
///   this game-over flow. Ads never show during play.
class ResultsScreen extends StatefulWidget {
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
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final AppServices _s = ServicesScope.of(context);
  bool _reviewAsked = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (widget.record.newBest) unawaited(_maybeAskReview());
  }

  bool _started = false;

  Future<void> _maybeAskReview() async {
    final asked = await _s.review.maybeAsk();
    if (asked && mounted) setState(() => _reviewAsked = true);
  }

  Future<void> _leave({required bool playAgain}) async {
    if (_busy) return;
    setState(() => _busy = true);
    final name = playAgain ? 'results_play_again' : 'results_home';
    if (!_reviewAsked) {
      final shown = await _s.ads.maybeShowInterstitial(
        InterstitialTrigger(
          name: name,
          completedGames: _s.progress.gamesPlayed,
          gameDuration: widget.gameDuration,
          rewardedWatchedThisFlow: widget.rewardedWatched,
        ),
      );
      Logger('results').info('$name: interstitial shown $shown');
      if (shown) {
        _s.analytics.logEvent(AnalyticsEvents.adInterstitialShown, {
          'trigger': name,
        });
      }
    }
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (playAgain) {
      await nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => GameScreen.newGame(_s, widget.mode),
        ),
      );
    } else {
      nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final record = widget.record;
    final daily = widget.mode == GameMode.daily;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
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
                        Text(
                          '${record.score}',
                          style: theme.textTheme.displayLarge,
                        ),
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
                          onPressed: _busy
                              ? null
                              : () => _leave(playAgain: true),
                        ),
                        const SizedBox(height: GameSpacing.md),
                        GameButton(
                          label: 'Home',
                          icon: Icons.home_rounded,
                          style: GameButtonStyle.secondary,
                          onPressed: _busy
                              ? null
                              : () => _leave(playAgain: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Banner on the Results screen only (ADR 007): anchored at the
            // bottom, its height reserved before it loads, and well clear of
            // the buttons. Never during play.
            const SizedBox(height: GameSpacing.md),
            _s.ads.buildBanner(),
          ],
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
