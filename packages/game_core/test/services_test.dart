import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Logger', () {
    late List<String> lines;
    setUp(() {
      lines = [];
      Logger.output = lines.add;
      Logger.releaseMode = false;
      Logger.minLevel = LogLevel.debug;
      Logger.errorSink = null;
    });

    test('prints tagged lines at or above minLevel', () {
      Logger.minLevel = LogLevel.info;
      final log = Logger('t');
      log.debug('hidden');
      log.info('hello');
      log.warning('careful', 'oops');
      log.error('bad', StateError('x'), StackTrace.empty);
      expect(lines[0], 'INFO [t] hello');
      expect(lines[1], 'WARNING [t] careful | oops');
      expect(lines[2], startsWith('ERROR [t] bad'));
      expect(lines.length, 4);
    });

    test('release prints nothing and sends only errors to the sink', () {
      Logger.releaseMode = true;
      final sunk = <String>[];
      Logger.errorSink = (m, e, s) => sunk.add(m);
      final log = Logger('r');
      log.info('x');
      log.warning('y');
      log.error('z');
      expect(lines, isEmpty);
      expect(sunk, ['[r] z']);
    });
  });

  group('KeyValueStore', () {
    Future<void> exercise(KeyValueStore s) async {
      expect(s.getInt('i'), isNull);
      expect(s.getIntOr('i', 7), 7);
      expect(s.getBoolOr('b', true), isTrue);
      await s.setInt('i', 3);
      await s.setBool('b', false);
      await s.setString('s', 'hi');
      await s.setJson('j', {
        'a': 1,
        'b': [1, 2],
      });
      expect(s.getInt('i'), 3);
      expect(s.getBool('b'), isFalse);
      expect(s.getString('s'), 'hi');
      expect(s.getJson('j'), {
        'a': 1,
        'b': [1, 2],
      });
      expect(s.containsKey('s'), isTrue);
      await s.setString('bad', '{not json');
      expect(s.getJson('bad'), isNull);
      await s.setString('list', '[1]');
      expect(s.getJson('list'), isNull);
      expect(s.getJson('missing'), isNull);
      await s.remove('s');
      expect(s.containsKey('s'), isFalse);
    }

    test('InMemoryStore', () => exercise(InMemoryStore()));

    test('SharedPrefsStore', () async {
      SharedPreferences.setMockInitialValues({});
      await exercise(await SharedPrefsStore.open());
    });
  });

  test('Settings load defaults, persist changes and reload', () async {
    final store = InMemoryStore();
    final s = Settings(store);
    expect(s.sound.value, isTrue);
    expect(s.colourBlindPatterns.value, isFalse);
    s.sound.value = false;
    s.colourBlindPatterns.value = true;
    s.music.value = false;
    s.haptics.value = false;
    final reloaded = Settings(store);
    expect(reloaded.sound.value, isFalse);
    expect(reloaded.music.value, isFalse);
    expect(reloaded.haptics.value, isFalse);
    expect(reloaded.colourBlindPatterns.value, isTrue);
    s.dispose();
    reloaded.dispose();
  });

  group('PlatformHaptics', () {
    late List<String> calls;
    setUp(() {
      calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              calls.add(call.arguments as String);
            }
            return null;
          });
    });

    test('plays patterns when enabled', () async {
      final h = PlatformHaptics(ValueNotifier(true), successGap: Duration.zero);
      await h.play(HapticPattern.light);
      await h.play(HapticPattern.medium);
      await h.play(HapticPattern.success);
      expect(calls, [
        'HapticFeedbackType.lightImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.mediumImpact',
        'HapticFeedbackType.heavyImpact',
      ]);
    });

    test('silent when disabled', () async {
      await PlatformHaptics(ValueNotifier(false)).play(HapticPattern.medium);
      expect(calls, isEmpty);
    });

    test('fake records', () async {
      final f = FakeHaptics();
      await f.play(HapticPattern.success);
      expect(f.played, [HapticPattern.success]);
    });
  });

  group('ReviewPrompter', () {
    late DateTime now;
    late InMemoryStore store;
    late FakeReviewRequester requester;
    late ReviewPrompter prompter;

    setUp(() {
      now = DateTime(2027, 1, 1);
      store = InMemoryStore();
      requester = FakeReviewRequester();
      prompter = ReviewPrompter(
        store: store,
        requester: requester,
        clock: () => now,
        minDaysBetween: 30,
      );
    });

    test('never in the first session', () async {
      await prompter.onSessionStart();
      expect(await prompter.maybeAsk(), isFalse);
      expect(requester.requests, 0);
    });

    test('asks in a later session, then not again for 30 days', () async {
      await prompter.onSessionStart();
      await prompter.onSessionStart();
      expect(await prompter.maybeAsk(), isTrue);
      expect(await prompter.maybeAsk(), isFalse);
      now = now.add(const Duration(days: 29));
      expect(await prompter.maybeAsk(), isFalse);
      now = now.add(const Duration(days: 1));
      expect(await prompter.maybeAsk(), isTrue);
      expect(requester.requests, 2);
    });

    test('does nothing when the store API is unavailable', () async {
      requester.available = false;
      await prompter.onSessionStart();
      await prompter.onSessionStart();
      expect(await prompter.maybeAsk(), isFalse);
      expect(prompter.eligible, isTrue);
    });
  });

  test('analytics fakes', () async {
    final a = RecordingAnalytics();
    await a.logEvent(AnalyticsEvents.gameEnd, {'score': 10});
    await const NoopAnalytics().logEvent(AnalyticsEvents.gameStart);
    expect(a.names, ['game_end']);
    expect(a.events.single.$2, {'score': 10});
  });

  test('consent, crash and audio fakes', () async {
    final c = FakeConsentService(canRequestAds: false);
    await c.gather();
    await c.showPrivacyOptionsForm();
    expect((c.gatherCalls, c.privacyFormShows, c.canRequestAds), (1, 1, false));

    final r = NoopCrashReporter();
    await r.install();
    await r.recordError('e', null);
    expect(r.recorded, ['e']);

    final audio = FakeAudioService<HapticPattern>();
    await audio.preload();
    await audio.play(HapticPattern.light, rate: 1.2);
    await audio.startMusic();
    audio.onLifecycle(AppLifecycleState.paused);
    expect(audio.played.single, (HapticPattern.light, 1.2));
    expect(audio.musicPlaying, isTrue);
    await audio.stopMusic();
    expect(audio.musicPlaying, isFalse);
    expect(audio.lastLifecycle, AppLifecycleState.paused);
    await audio.dispose();
  });

  test('house ads exclude the current app and cycle', () {
    const all = [
      HouseAd(packageId: 'com.omarfahd.a', title: 'A', tagline: 'a'),
      HouseAd(packageId: 'com.omarfahd.b', title: 'B', tagline: 'b'),
      HouseAd(packageId: 'com.omarfahd.c', title: 'C', tagline: 'c'),
    ];
    const h = HouseAds(currentPackageId: 'com.omarfahd.b', all: all);
    expect(h.available.map((a) => a.title), ['A', 'C']);
    expect(h.pick(3)!.title, 'C');
    expect(h.pick(0)!.storeUri.queryParameters['id'], 'com.omarfahd.a');
    expect(const HouseAds(currentPackageId: 'x').pick(0), isNull);
  });
}
