import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:game_core/game_core.dart';

import '../../constants.dart';
import '../block_game.dart';

/// Score, best score and streak above the board.
class HudComponent extends PositionComponent with HasGameReference<BlockGame> {
  late final TextComponent _score;
  late final TextComponent _best;
  late final TextComponent _streak;

  static TextPaint _paint(double size, Color colour, FontWeight w) => TextPaint(
    style: TextStyle(
      fontFamily: kGameFontFamily,
      fontSize: size,
      fontWeight: w,
      color: colour,
    ),
  );

  @override
  Future<void> onLoad() async {
    _score = TextComponent(
      text: '0',
      anchor: Anchor.center,
      textRenderer: _paint(44, GameColors.textPrimary, FontWeight.w900),
    );
    _best = TextComponent(
      text: '',
      anchor: Anchor.topLeft,
      textRenderer: _paint(16, GameColors.textSecondary, FontWeight.w700),
    );
    _streak = TextComponent(
      text: '',
      anchor: Anchor.center,
      textRenderer: _paint(20, GameColors.accent, FontWeight.w900),
    );
    addAll([_score, _best, _streak]);
    refresh(animate: false);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final hud = game.layout.hud;
    final board = game.layout.board;
    position = Vector2(hud.left, hud.top);
    this.size = Vector2(hud.width, hud.height);
    if (!isLoaded) return;
    _score.position = Vector2(hud.width / 2, hud.height * 0.5);
    _best.position = Vector2(board.left - hud.left, hud.height * 0.08);
    _streak.position = Vector2(hud.width / 2, hud.height * 0.86);
  }

  void refresh({required bool animate, bool streakUp = false}) {
    if (!isLoaded) return;
    final s = game.controller.state;
    _score.text = '${s.score}';
    final best = s.score > game.best ? s.score : game.best;
    _best.text = best > 0 ? 'Best $best' : '';
    final streak = s.streak.streak;
    _streak.text = streak > 0 ? 'Streak x${streak + 1}' : '';
    if (animate && streakUp && streak > 0) {
      _pulse(_streak, kStreakPulseScale);
    }
  }

  void celebrateBest() => _pulse(_best, 1.3);

  void _pulse(PositionComponent c, double to) {
    c.children.whereType<Effect>().toList().forEach(
      (e) => e.removeFromParent(),
    );
    c.scale = Vector2.all(1);
    c.add(
      ScaleEffect.to(
        Vector2.all(to),
        EffectController(
          duration: kStreakPulseDuration / 2,
          reverseDuration: kStreakPulseDuration / 2,
          curve: Curves.easeOut,
        ),
      ),
    );
  }
}
