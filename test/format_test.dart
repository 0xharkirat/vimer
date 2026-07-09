import 'package:flutter_test/flutter_test.dart';
import 'package:vimer/src/util/format.dart';

void main() {
  group('formatStopwatch', () {
    test('shows centiseconds under an hour', () {
      expect(formatStopwatch(Duration.zero), '00:00.00');
      expect(
        formatStopwatch(const Duration(minutes: 1, seconds: 23, milliseconds: 456)),
        '01:23.45',
      );
      expect(formatStopwatch(const Duration(seconds: 9, milliseconds: 990)), '00:09.99');
    });

    test('drops centiseconds past an hour', () {
      expect(formatStopwatch(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
    });

    test('clamps negatives to zero', () {
      expect(formatStopwatch(const Duration(seconds: -5)), '00:00.00');
    });
  });
}
