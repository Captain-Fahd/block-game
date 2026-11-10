import 'package:flutter/material.dart';

import 'tokens.dart';

enum GameButtonStyle { primary, secondary }

/// Chunky rounded button with a pressed-down offset, used on every screen.
class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = GameButtonStyle.primary,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonStyle style;
  final bool expand;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.style == GameButtonStyle.primary;
    final enabled = widget.onPressed != null;
    final face = primary ? GameColors.accent : GameColors.surfaceRaised;
    final edge = primary ? GameColors.accentPressed : GameColors.gridLine;
    final fg = primary ? GameColors.onAccent : GameColors.textPrimary;
    const depth = 5.0;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: 22),
          const SizedBox(width: GameSpacing.sm),
        ],
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kGameFontFamily,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                widget.onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: SizedBox(
            width: widget.expand ? double.infinity : null,
            height: 60,
            child: Stack(
              children: [
                Positioned.fill(
                  top: depth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: edge,
                      borderRadius: BorderRadius.circular(GameSpacing.radius),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 60),
                  left: 0,
                  right: 0,
                  top: _down ? depth : 0,
                  bottom: _down ? 0 : depth,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: GameSpacing.lg,
                    ),
                    decoration: BoxDecoration(
                      color: face,
                      borderRadius: BorderRadius.circular(GameSpacing.radius),
                    ),
                    alignment: Alignment.center,
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog with the shared look: title, body, stacked actions.
class GameDialog extends StatelessWidget {
  const GameDialog({
    super.key,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final String title;
  final Widget? body;
  final List<Widget> actions;

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    Widget? body,
    List<Widget> actions = const [],
    bool dismissible = true,
  }) => showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    builder: (_) => GameDialog(title: title, body: body, actions: actions),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.all(GameSpacing.lg),
      child: Padding(
        padding: const EdgeInsets.all(GameSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineMedium,
            ),
            if (body != null) ...[
              const SizedBox(height: GameSpacing.md),
              DefaultTextStyle.merge(
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameColors.textSecondary),
                child: body!,
              ),
            ],
            for (final a in actions) ...[
              const SizedBox(height: GameSpacing.md),
              a,
            ],
          ],
        ),
      ),
    );
  }
}
