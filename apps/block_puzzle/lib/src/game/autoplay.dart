import 'dart:developer' show Timeline;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:game_core/game_core.dart';

import '../constants.dart';
import '../model/board.dart';
import '../model/game_controller.dart';
import '../model/game_state.dart';
import 'block_game.dart';

/// Debug/profile-only: `--dart-define=AUTOPLAY=true` makes the game play
/// itself through the normal drag path, for on-device checks of effects and
/// frame times. Never active in release builds.
const bool kAutoplay = bool.fromEnvironment('AUTOPLAY') && !kReleaseMode;

/// With autoplay, also turn sound off (to isolate audio cost when
/// profiling).
const bool kAutoplayMute = kAutoplay && bool.fromEnvironment('AUTOPLAY_MUTE');

/// Greedy bot: picks the move that clears the most lines (then the one
/// that leaves the fewest filled cells) and drags it there over a few
/// frames, like a quick human.
class Autoplay extends Component with HasGameReference<BlockGame> {
  Autoplay({this.pause = 0.35, this.dragTime = 0.22});

  final double pause;
  final double dragTime;
  double _wait = 1;
  _Move? _move;
  double _t = 0;
  int _games = 0;
  int _clearsLogged = 0;

  @override
  void onMount() {
    super.onMount();
    // The bot computes exact 1:1 finger paths.
    game.dragAcceleration = false;
  }

  @override
  void update(double dt) {
    final m = _move;
    if (m != null) {
      _t += dt;
      final k = (_t / dragTime).clamp(0.0, 1.0);
      game.moveDrag(Offset.lerp(m.from, m.to, k)!);
      if (k >= 1) {
        final r = game.endDrag();
        if (r != null && r.linesCleared > 0 && _clearsLogged < 3) {
          _clearsLogged++;
          Logger('frames').info(
            'clear #$_clearsLogged (${r.linesCleared} lines) at '
            '${Timeline.now ~/ 1000} ms',
          );
        }
        _move = null;
        _wait = pause;
      }
      return;
    }
    _wait -= dt;
    if (_wait > 0) return;
    if (game.controller.isOver) {
      _games++;
      game.startGame(
        GameController.newGame(mode: GameMode.classic, seed: 1000 + _games),
      );
      _wait = 1;
      return;
    }
    _startMove();
  }

  /// Longest time spent choosing a move since the last read (µs). The bot
  /// runs on the UI thread, so this is subtracted from the game's budget.
  static int maxPlanUs = 0;

  void _startMove() {
    final sw = Stopwatch()..start();
    try {
      _plan();
    } finally {
      if (sw.elapsedMicroseconds > maxPlanUs) {
        maxPlanUs = sw.elapsedMicroseconds;
      }
    }
  }

  void _plan() {
    final s = game.controller.state;
    ({int slot, int row, int col})? best;
    var bestScore = -1 << 30;
    for (var slot = 0; slot < s.tray.length; slot++) {
      final p = s.tray[slot];
      if (p == null) continue;
      for (final pos in s.board.validPositions(p)) {
        final placed = s.board.place(p, pos.row, pos.col);
        final lines = placed.findFullLines();
        final after = placed.clearLines(lines);
        final score =
            (lines.rows.length + lines.cols.length) * 100 -
            after.filledCount -
            _holes(after);
        if (score > bestScore) {
          bestScore = score;
          best = (slot: slot, row: pos.row, col: pos.col);
        }
      }
    }
    if (best == null) return;
    final piece = s.tray[best.slot]!;
    final home = game.slots[best.slot].home;
    final from = Offset(home.x, home.y);
    if (!game.startDrag(best.slot, from)) return;
    final tl = game.layout.cellRect(best.row, best.col).topLeft;
    final to = Offset(
      tl.dx + piece.width * game.dragCell / 2,
      tl.dy +
          kDragFingerOffsetCells * game.layout.cell +
          piece.height * game.dragCell,
    );
    _move = _Move(from, to);
    _t = 0;
  }

  /// Empty cells with all four neighbours filled (hard to use later).
  int _holes(Board b) {
    var n = 0;
    for (var r = 0; r < b.size; r++) {
      for (var c = 0; c < b.size; c++) {
        if (b.isFilled(r, c)) continue;
        bool f(int rr, int cc) =>
            rr < 0 ||
            cc < 0 ||
            rr >= b.size ||
            cc >= b.size ||
            b.isFilled(rr, cc);
        if (f(r - 1, c) && f(r + 1, c) && f(r, c - 1) && f(r, c + 1)) n++;
      }
    }
    return n;
  }
}

class _Move {
  _Move(this.from, this.to);
  final Offset from;
  final Offset to;
}

/// Logs frame build/raster times every [every] frames (profile builds give
/// meaningful numbers; debug builds are much slower).
class FrameStats {
  FrameStats({this.every = 300, this.extra}) : _log = Logger('frames');

  final int every;

  /// Extra diagnostics appended to each line (e.g. component counts).
  final String Function()? extra;
  final Logger _log;
  final List<int> _totalUs = [];
  final List<int> _rasterUs = [];
  int _batches = 0;

  void start() => SchedulerBinding.instance.addTimingsCallback(_onTimings);

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      if (_batches == 0 && t.totalSpan.inMicroseconds > 16667) {
        _log.info(
          'slow frame at '
          '${t.timestampInMicroseconds(FramePhase.vsyncStart) ~/ 1000} ms: '
          'build ${t.buildDuration.inMicroseconds / 1000} ms, '
          'raster ${t.rasterDuration.inMicroseconds / 1000} ms, '
          'total ${t.totalSpan.inMicroseconds / 1000} ms',
        );
      }
      _totalUs.add(t.totalSpan.inMicroseconds);
      _rasterUs.add(t.rasterDuration.inMicroseconds);
    }
    if (_totalUs.length < every) return;
    if (_batches == 0) {
      _log.info('first batch ends at ${Timeline.now ~/ 1000} ms');
    }
    _batches++;
    final total = [..._totalUs]..sort();
    final raster = [..._rasterUs]..sort();
    int pct(List<int> l, double p) => l[((l.length - 1) * p).round()];
    final slow = total.where((us) => us > 16667).length;
    _log.info(
      'batch $_batches: ${total.length} frames, '
      'total p50 ${pct(total, .5) / 1000} ms, p95 ${pct(total, .95) / 1000} ms, '
      'p99 ${pct(total, .99) / 1000} ms, max ${total.last / 1000} ms; '
      'raster p95 ${pct(raster, .95) / 1000} ms; '
      'over 16.7 ms: $slow; bot plan max ${Autoplay.maxPlanUs / 1000} ms'
      '${extra == null ? '' : '; ${extra!()}'}',
    );
    Autoplay.maxPlanUs = 0;
    _totalUs.clear();
    _rasterUs.clear();
  }
}
