import 'package:in_app_review/in_app_review.dart';

import 'clock.dart';
import 'logger.dart';
import 'storage.dart';

abstract class ReviewRequester {
  Future<bool> isAvailable();
  Future<void> requestReview();
}

class InAppReviewRequester implements ReviewRequester {
  final _r = InAppReview.instance;
  @override
  Future<bool> isAvailable() => _r.isAvailable();
  @override
  Future<void> requestReview() => _r.requestReview();
}

class FakeReviewRequester implements ReviewRequester {
  FakeReviewRequester({this.available = true});
  bool available;
  int requests = 0;
  @override
  Future<bool> isAvailable() async => available;
  @override
  Future<void> requestReview() async => requests++;
}

/// Decides when to ask for a store review.
///
/// Only call [maybeAsk] after a positive moment (new best score, Nth win),
/// never after a loss. It never asks in the first session, and at most once
/// every [minDaysBetween] days.
class ReviewPrompter {
  ReviewPrompter({
    required this.store,
    required this.requester,
    this.clock = systemClock,
    this.minDaysBetween = 30,
  });

  final KeyValueStore store;
  final ReviewRequester requester;
  final Clock clock;
  final int minDaysBetween;
  final _log = Logger('review');

  static const _kSessions = 'review.sessions';
  static const _kLastAsk = 'review.lastAskMs';

  int get sessionCount => store.getIntOr(_kSessions, 0);

  /// Call once per app launch.
  Future<void> onSessionStart() => store.setInt(_kSessions, sessionCount + 1);

  bool get eligible {
    if (sessionCount <= 1) return false;
    final last = store.getInt(_kLastAsk);
    if (last == null) return true;
    final since = clock().difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since.inDays >= minDaysBetween;
  }

  /// Returns true if the review flow was requested.
  Future<bool> maybeAsk() async {
    if (!eligible) return false;
    try {
      if (!await requester.isAvailable()) return false;
      await store.setInt(_kLastAsk, clock().millisecondsSinceEpoch);
      await requester.requestReview();
      return true;
    } on Object catch (e) {
      _log.warning('review request failed', e);
      return false;
    }
  }
}
