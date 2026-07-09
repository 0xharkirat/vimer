import 'package:flutter_test/flutter_test.dart';
import 'package:vimer/src/services/duration_parser.dart';

void main() {
  group('single unit', () {
    test('minutes', () {
      expect(parseCommand('5m')?.duration, const Duration(minutes: 5));
    });
    test('hours', () {
      expect(parseCommand('5h')?.duration, const Duration(hours: 5));
    });
    test('seconds', () {
      expect(parseCommand('5s')?.duration, const Duration(seconds: 5));
    });
    test('long form words', () {
      expect(parseCommand('2 hours')?.duration, const Duration(hours: 2));
      expect(parseCommand('30 min')?.duration, const Duration(minutes: 30));
      expect(parseCommand('45 seconds')?.duration, const Duration(seconds: 45));
    });
  });

  group('combined units', () {
    test('h m s', () {
      expect(
        parseCommand('5h5m30s')?.duration,
        const Duration(hours: 5, minutes: 5, seconds: 30),
      );
    });
    test('with spaces', () {
      expect(
        parseCommand('1h 30m')?.duration,
        const Duration(hours: 1, minutes: 30),
      );
    });
    test('overflow values sum', () {
      expect(parseCommand('90m')?.duration, const Duration(minutes: 90));
      expect(parseCommand('90s')?.duration, const Duration(seconds: 90));
    });
    test('decimal', () {
      expect(parseCommand('1.5h')?.duration, const Duration(minutes: 90));
      expect(parseCommand('0.5m')?.duration, const Duration(seconds: 30));
    });
  });

  group('colon format', () {
    test('mm:ss', () {
      expect(parseCommand('25:00')?.duration, const Duration(minutes: 25));
      expect(
        parseCommand('05:30')?.duration,
        const Duration(minutes: 5, seconds: 30),
      );
    });
    test('mm:ss allows minutes over 59', () {
      expect(parseCommand('90:00')?.duration, const Duration(minutes: 90));
    });
    test('hh:mm:ss', () {
      expect(
        parseCommand('1:30:00')?.duration,
        const Duration(hours: 1, minutes: 30),
      );
    });
    test('rejects out-of-range seconds', () {
      expect(parseCommand('1:99'), isNull);
    });
  });

  group('bare number is minutes', () {
    test('integer', () {
      expect(parseCommand('25')?.duration, const Duration(minutes: 25));
    });
    test('decimal', () {
      expect(parseCommand('0.5')?.duration, const Duration(seconds: 30));
    });
  });

  group('labels', () {
    test('trailing label', () {
      final r = parseCommand('25m deep work');
      expect(r?.duration, const Duration(minutes: 25));
      expect(r?.label, 'deep work');
    });
    test('leading label', () {
      final r = parseCommand('deep work 25m');
      expect(r?.duration, const Duration(minutes: 25));
      expect(r?.label, 'deep work');
    });
    test('label with number kept', () {
      final r = parseCommand('phase 2 25m');
      expect(r?.duration, const Duration(minutes: 25));
      expect(r?.label, 'phase 2');
    });
    test('bare number with label', () {
      final r = parseCommand('25 tea');
      expect(r?.duration, const Duration(minutes: 25));
      expect(r?.label, 'tea');
    });
    test('no label -> null label', () {
      expect(parseCommand('5m')?.label, isNull);
    });
    test('non-unit tokens survive in label', () {
      final r = parseCommand('5k run 30m');
      expect(r?.duration, const Duration(minutes: 30));
      expect(r?.label, '5k run');
    });
  });

  group('invalid input', () {
    test('empty', () {
      expect(parseCommand(''), isNull);
      expect(parseCommand('   '), isNull);
    });
    test('no duration', () {
      expect(parseCommand('hello'), isNull);
    });
    test('zero', () {
      expect(parseCommand('0'), isNull);
      expect(parseCommand('0m'), isNull);
      expect(parseCommand('00:00'), isNull);
    });
  });

  group('clamping', () {
    test('caps absurd durations', () {
      expect(parseCommand('9999h')?.duration, const Duration(hours: 99, minutes: 59, seconds: 59));
    });
  });

  group('kind + tags', () {
    test('plain duration is a countdown', () {
      expect(parseCommand('5m')?.kind, CommandKind.countdown);
      expect(parseCommand('5m')?.tags, isEmpty);
    });
    test('extracts and strips tags', () {
      final r = parseCommand('25m deep work #focus #v2');
      expect(r?.duration, const Duration(minutes: 25));
      expect(r?.label, 'deep work');
      expect(r?.tags, ['focus', 'v2']);
    });
    test('tag before duration, lowercased', () {
      final r = parseCommand('#Work 30m');
      expect(r?.duration, const Duration(minutes: 30));
      expect(r?.tags, ['work']);
    });
  });

  group('@time alarms', () {
    final now = DateTime(2026, 1, 1, 10, 0); // 10:00 AM
    test('@3pm today', () {
      final r = parseCommand('@3pm', now: now);
      expect(r?.kind, CommandKind.alarm);
      expect(r?.fireAt, DateTime(2026, 1, 1, 15, 0));
      expect(r?.duration, const Duration(hours: 5));
    });
    test('@3:30pm with label and tag', () {
      final r = parseCommand('standup @3:30pm #team', now: now);
      expect(r?.kind, CommandKind.alarm);
      expect(r?.fireAt, DateTime(2026, 1, 1, 15, 30));
      expect(r?.label, 'standup');
      expect(r?.tags, ['team']);
    });
    test('24h format', () {
      expect(parseCommand('@14:00', now: now)?.fireAt, DateTime(2026, 1, 1, 14, 0));
    });
    test('past time rolls to tomorrow', () {
      expect(parseCommand('@9am', now: now)?.fireAt, DateTime(2026, 1, 2, 9, 0));
    });
    test('noon / midnight / 12pm / 12am', () {
      expect(parseCommand('@noon', now: now)?.fireAt, DateTime(2026, 1, 1, 12, 0));
      expect(parseCommand('@midnight', now: now)?.fireAt, DateTime(2026, 1, 2, 0, 0));
      expect(parseCommand('@12pm', now: now)?.fireAt, DateTime(2026, 1, 1, 12, 0));
      expect(parseCommand('@12am', now: now)?.fireAt, DateTime(2026, 1, 2, 0, 0));
    });
  });

  group('stopwatch', () {
    test('stopwatch keyword', () {
      expect(parseCommand('stopwatch')?.kind, CommandKind.stopwatch);
      expect(parseCommand('stopwatch')?.duration, isNull);
    });
    test('sw alias with label and tag', () {
      final r = parseCommand('sw deep work #coding');
      expect(r?.kind, CommandKind.stopwatch);
      expect(r?.label, 'deep work');
      expect(r?.tags, ['coding']);
    });
  });
}
