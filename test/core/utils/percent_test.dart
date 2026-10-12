import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/utils/percent.dart';

void main() {
  group('formatPercent', () {
    test('rounds half up', () {
      expect(formatPercent(1, 4), '25%');
      expect(formatPercent(1, 3), '33%');
      expect(formatPercent(2, 3), '67%');
      expect(formatPercent(1, 8), '13%'); // 12.5
      expect(formatPercent(5, 5), '100%');
    });

    test('shows a tiny share as <1% and nothing as 0%', () {
      expect(formatPercent(1, 1000), '<1%');
      expect(formatPercent(0, 1000), '0%');
      expect(formatPercent(-5, 100), '0%');
    });

    test('a zero whole is 0%', () {
      expect(formatPercent(100, 0), '0%');
    });

    test('works with big amounts', () {
      expect(formatPercent(99999999999999, 99999999999999), '100%');
    });
  });

  group('percentChange', () {
    test('is the change from previous to current', () {
      expect(percentChange(current: 150, previous: 100), 50);
      expect(percentChange(current: 50, previous: 100), -50);
      expect(percentChange(current: 100, previous: 100), 0);
      expect(percentChange(current: 300, previous: 100), 200);
    });

    test('rounds half away from zero', () {
      expect(percentChange(current: 103, previous: 200), -49); // -48.5
      expect(percentChange(current: 201, previous: 200), 1); // 0.5
      expect(percentChange(current: 199, previous: 200), -1); // -0.5
      expect(percentChange(current: 4, previous: 3), 33);
    });

    test('is null when there was nothing before', () {
      expect(percentChange(current: 100, previous: 0), isNull);
      expect(percentChange(current: 0, previous: 0), isNull);
    });

    test('going to zero is -100%', () {
      expect(percentChange(current: 0, previous: 500), -100);
    });
  });
}
