import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:game_core/game_core.dart';

import 'src/game/autoplay.dart';
import 'src/game/block_game.dart';
import 'src/game/sfx.dart';
import 'src/model/game_controller.dart';
import 'src/model/game_state.dart';

// Phase 4 shell: straight into a Classic game. Home, settings, resume and
// the real game-over flow arrive in Phase 5.

const _kBestClassic = 'best.classic';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = await SharedPrefsStore.open();
  final settings = Settings(store);
  final audio = FlameAudioService<Sfx>(
    files: kSfxFiles,
    sound: settings.sound,
    music: settings.music,
  );
  unawaited(audio.preload());
  runApp(
    BlockPuzzleApp(
      store: store,
      settings: settings,
      audio: audio,
      haptics: PlatformHaptics(settings.haptics),
    ),
  );
}

/// Seeds come from the clock here in the UI layer; the model only ever sees
/// the number.
int newSeed() => DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF;

class BlockPuzzleApp extends StatefulWidget {
  const BlockPuzzleApp({
    super.key,
    required this.store,
    required this.settings,
    required this.audio,
    required this.haptics,
  });

  final KeyValueStore store;
  final Settings settings;
  final AudioService<Sfx> audio;
  final Haptics haptics;

  @override
  State<BlockPuzzleApp> createState() => _BlockPuzzleAppState();
}

class _BlockPuzzleAppState extends State<BlockPuzzleApp>
    with WidgetsBindingObserver {
  late final BlockGame _game = BlockGame(
    controller: GameController.newGame(mode: GameMode.classic, seed: newSeed()),
    audio: widget.audio,
    haptics: widget.haptics,
    colourBlind: widget.settings.colourBlindPatterns,
    best: widget.store.getIntOr(_kBestClassic, 0),
    onGameOver: _onGameOver,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (kAutoplay) {
      _game.add(Autoplay());
      FrameStats(
        extra: () =>
            'components ${_game.descendants().length}, '
            'play children ${_game.play.children.length}',
      ).start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.audio.onLifecycle(state);

  void _onGameOver(BlockGame game) {
    if (kAutoplay) return;
    final score = game.controller.state.score;
    if (score > widget.store.getIntOr(_kBestClassic, 0)) {
      widget.store.setInt(_kBestClassic, score);
    }
    game.overlays.add(_GameOverPanel.id);
  }

  void _playAgain() {
    _game.overlays.remove(_GameOverPanel.id);
    _game.startGame(
      GameController.newGame(mode: GameMode.classic, seed: newSeed()),
      best: widget.store.getIntOr(_kBestClassic, 0),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Block Puzzle',
    debugShowCheckedModeBanner: false,
    theme: buildGameTheme(),
    home: Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: GameWidget<BlockGame>(
          game: _game,
          overlayBuilderMap: {
            _GameOverPanel.id: (context, game) =>
                _GameOverPanel(game: game, onPlayAgain: _playAgain),
          },
        ),
      ),
    ),
  );
}

class _GameOverPanel extends StatelessWidget {
  const _GameOverPanel({required this.game, required this.onPlayAgain});

  static const id = 'gameOver';
  final BlockGame game;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = game.controller.state.score;
    return ColoredBox(
      color: GameColors.background.withValues(alpha: 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(GameSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('No moves left', style: theme.textTheme.headlineMedium),
              const SizedBox(height: GameSpacing.md),
              Text('$score', style: theme.textTheme.displayLarge),
              const SizedBox(height: GameSpacing.xl),
              GameButton(label: 'Play again', onPressed: onPlayAgain),
            ],
          ),
        ),
      ),
    );
  }
}
