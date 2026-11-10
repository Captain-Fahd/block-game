import 'package:flutter/painting.dart';

/// Shared colour tokens. Games pick from these; nothing hard-codes colours.
abstract final class GameColors {
  static const background = Color(0xFF14172B);
  static const backgroundTop = Color(0xFF1E2340);
  static const surface = Color(0xFF232846);
  static const surfaceRaised = Color(0xFF2D3357);
  static const boardWell = Color(0xFF0F1222);
  static const gridLine = Color(0xFF2A2F4F);
  static const textPrimary = Color(0xFFF4F5FB);
  static const textSecondary = Color(0xFFA9AECB);
  static const accent = Color(0xFFFFC54D);
  static const accentPressed = Color(0xFFE0A930);
  static const onAccent = Color(0xFF23190A);
  static const danger = Color(0xFFFF5C6C);
  static const success = Color(0xFF4CD38A);

  /// Default block colours (index = piece colour index).
  static const blocks = <Color>[
    Color(0xFFFF6B6B), // coral
    Color(0xFFFFA94D), // orange
    Color(0xFFFFD43B), // yellow
    Color(0xFF69DB7C), // green
    Color(0xFF38D9A9), // teal
    Color(0xFF4DABF7), // blue
    Color(0xFF9775FA), // violet
    Color(0xFFF783AC), // pink
  ];

  /// Colour-blind-safe set (based on the Okabe–Ito palette), used together
  /// with [BlockPattern] overlays so colour is never the only cue.
  static const blocksColourBlind = <Color>[
    Color(0xFFE69F00), // orange
    Color(0xFF56B4E9), // sky blue
    Color(0xFF009E73), // bluish green
    Color(0xFFF0E442), // yellow
    Color(0xFF0072B2), // blue
    Color(0xFFD55E00), // vermillion
    Color(0xFFCC79A7), // reddish purple
    Color(0xFFBBBBBB), // grey
  ];
}

/// Overlay pattern per colour index in colour-blind mode.
enum BlockPattern { none, dot, ring, stripeH, stripeV, diagonal, cross, square }

const List<BlockPattern> kBlockPatterns = BlockPattern.values;

abstract final class GameSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const radius = 16.0;
  static const radiusSmall = 10.0;
}

/// Bundled OFL font (Nunito, variable weight). Licence in assets/fonts.
const String kGameFontFamily = 'packages/game_core/Nunito';
