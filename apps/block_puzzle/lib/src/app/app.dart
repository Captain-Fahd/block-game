import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '../ui/home_screen.dart';
import '../ui/tutorial_screen.dart';
import 'services.dart';

/// Root widget: provides [AppServices], applies the theme, forwards app
/// lifecycle to audio, and starts with the tutorial on first launch,
/// otherwise Home.
class BlockPuzzleApp extends StatefulWidget {
  const BlockPuzzleApp({super.key, required this.services, this.home});

  final AppServices services;

  /// Overrides the first screen (autoplay profiling goes straight to a game).
  final Widget? home;

  @override
  State<BlockPuzzleApp> createState() => _BlockPuzzleAppState();
}

class _BlockPuzzleAppState extends State<BlockPuzzleApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      widget.services.audio.onLifecycle(state);

  @override
  Widget build(BuildContext context) => ServicesScope(
    services: widget.services,
    child: MaterialApp(
      title: kAppTitle,
      debugShowCheckedModeBanner: false,
      theme: buildGameTheme(),
      home:
          widget.home ??
          (widget.services.progress.tutorialDone
              ? const HomeScreen()
              : const _FirstLaunch()),
    ),
  );
}

class _FirstLaunch extends StatelessWidget {
  const _FirstLaunch();

  @override
  Widget build(BuildContext context) => TutorialScreen(
    onDone: () => Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    ),
  );
}
