import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../app/services.dart';
import '../game/autoplay.dart';
import '../game/block_game.dart';
import '../model/daily_seed.dart';
import '../model/game_controller.dart';
import '../model/game_state.dart';
import 'overlays.dart';
import 'results_screen.dart';

/// Plays one game (new or resumed). Saves on every placement and when the
/// app is backgrounded; back / pause button opens the pause overlay; game
/// over offers a second chance (if a rewarded ad is ready) then goes to
/// Results.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  /// Starts a new game of [mode] (daily uses today's seed).
  factory GameScreen.newGame(AppServices s, GameMode mode) => GameScreen(
    controller: GameController.newGame(
      mode: mode,
      seed: mode == GameMode.daily ? dailySeed(s.clock()) : s.classicSeed(),
    ),
  );

  final GameController controller;

  @override
  State<GameScreen> createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  late final AppServices _s = ServicesScope.of(context);
  late final BlockGame game;
  final Stopwatch _played = Stopwatch();
  bool _rewardedWatched = false;
  bool _finishing = false;

  GameMode get mode => game.controller.state.mode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) return;
    _initialised = true;
    final m = widget.controller.state.mode;
    game = BlockGame(
      controller: widget.controller,
      audio: _s.audio,
      haptics: _s.haptics,
      colourBlind: _s.settings.colourBlindPatterns,
      best: _s.progress.bestFor(m),
      onPlacement: _onPlacement,
      onGameOver: (_) => _onGameOver(),
    );
    // In flow mode the bot plays slower so games pass the 30 s interstitial
    // minimum.
    if (kAutoplay) game.add(Autoplay(pause: kAutoplayFlow ? 1.0 : 0.35));
    _played.start();
    final fresh = widget.controller.state.placements == 0;
    if (fresh) {
      _s.analytics.logEvent(AnalyticsEvents.gameStart, GameEvents.mode(m.name));
      if (m == GameMode.daily) {
        _s.analytics.logEvent(AnalyticsEvents.dailyStart);
      }
    }
  }

  bool _initialised = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _save();
      _played.stop();
      if (!game.controller.isOver) pause();
    }
  }

  void _onPlacement(PlacementResult r) {
    _save();
    if (r.linesCleared > 0) {
      _s.analytics.logEvent(AnalyticsEvents.lineClear, {
        'lines': r.linesCleared,
        'streak': r.score.streakAfter.streak,
      });
    }
  }

  void _save() {
    if (_finishing) return;
    unawaited(_s.progress.saveGame(game.controller.state));
  }

  // --- Pause -----------------------------------------------------------------

  void pause() {
    if (game.overlays.isActive(PauseOverlay.id) || _finishing) return;
    game.cancelDrag();
    game.pauseEngine();
    _played.stop();
    game.overlays.add(PauseOverlay.id);
  }

  void resume() {
    game.overlays.remove(PauseOverlay.id);
    game.resumeEngine();
    _played.start();
  }

  void restart() {
    game.overlays.remove(PauseOverlay.id);
    game.resumeEngine();
    final next = GameController.newGame(
      mode: mode,
      seed: mode == GameMode.daily ? dailySeed(_s.clock()) : _s.classicSeed(),
    );
    game.startGame(next, best: _s.progress.bestFor(mode));
    _rewardedWatched = false;
    _played
      ..reset()
      ..start();
    _save();
    _s.analytics.logEvent(
      AnalyticsEvents.gameStart,
      GameEvents.mode(mode.name),
    );
  }

  void quitToHome() {
    _save();
    Navigator.of(context).pop();
  }

  // --- Game over -------------------------------------------------------------

  void _onGameOver() {
    // Plain autoplay restarts by itself; AUTOPLAY_FLOW runs the real flow.
    if (kAutoplay && !kAutoplayFlow) return;
    final c = game.controller;
    final offer = c.canUseSecondChance && _s.ads.isRewardedReady.value;
    if (offer) {
      _s.analytics.logEvent(AnalyticsEvents.adRewardedOffered);
    }
    _offerSecondChance = offer;
    game.overlays.add(GameOverOverlay.id);
    if (!offer) {
      // Show "No moves left" briefly, then results.
      Future<void>.delayed(const Duration(milliseconds: 900), finish);
    }
  }

  bool _offerSecondChance = false;
  bool get offerSecondChance => _offerSecondChance;

  Future<void> watchForSecondChance() async {
    final earned = await _s.ads.showRewarded();
    if (!mounted) return;
    if (!earned) {
      await finish();
      return;
    }
    _rewardedWatched = true;
    _s.analytics.logEvent(AnalyticsEvents.adRewardedCompleted);
    game.controller.useSecondChance();
    game.overlays.remove(GameOverOverlay.id);
    game.refreshTray();
    _save();
  }

  Future<void> finish() async {
    if (_finishing || !mounted) return;
    _finishing = true;
    _played.stop();
    final s = game.controller.state;
    final record = await _s.progress.recordGameEnd(s);
    _s.analytics.logEvent(
      AnalyticsEvents.gameEnd,
      GameEvents.gameEnd(
        mode: s.mode.name,
        score: s.score,
        durationSeconds: _played.elapsed.inSeconds,
        moves: s.placements,
        cause: game.controller.blockedPieces.map((p) => p.family).join(','),
      ),
    );
    if (s.mode == GameMode.daily) {
      _s.analytics.logEvent(AnalyticsEvents.dailyEnd, {'score': s.score});
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultsScreen(
          mode: s.mode,
          record: record,
          gameDuration: _played.elapsed,
          rewardedWatched: _rewardedWatched,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) return;
      if (game.overlays.isActive(PauseOverlay.id)) {
        resume();
      } else if (!_finishing && !game.controller.isOver) {
        pause();
      }
    },
    child: Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            GameWidget<BlockGame>(
              game: game,
              overlayBuilderMap: {
                PauseOverlay.id: (_, _) => PauseOverlay(screen: this),
                GameOverOverlay.id: (_, _) => GameOverOverlay(screen: this),
              },
            ),
            Positioned(
              top: GameSpacing.sm,
              right: GameSpacing.sm,
              child: IconButton(
                key: const Key('pause'),
                tooltip: 'Pause',
                iconSize: 30,
                color: GameColors.textSecondary,
                icon: const Icon(Icons.pause_rounded),
                onPressed: () {
                  UiSounds.play(context, UiSound.tap);
                  pause();
                },
              ),
            ),
            if (mode == GameMode.daily)
              const Positioned(
                top: GameSpacing.md,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Text(
                    'Daily challenge',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kGameFontFamily,
                      fontWeight: FontWeight.w800,
                      color: GameColors.accent,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
