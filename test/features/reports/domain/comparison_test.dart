import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/reports/domain/comparison.dart';

void main() {
  group('Comparison', () {
    test('is none when both periods have nothing', () {
      const c = Comparison(current: 0, previous: 0);

      expect(c.direction, ChangeDirection.none);
      expect(c.difference, 0);
      expect(c.percent, isNull);
    });

    test('is up when this period is bigger', () {
      const c = Comparison(current: 15000, previous: 10000);

      expect(c.direction, ChangeDirection.up);
      expect(c.difference, 5000);
      expect(c.percent, 50);
    });

    test('is down when this period is smaller', () {
      const c = Comparison(current: 7500, previous: 10000);

      expect(c.direction, ChangeDirection.down);
      expect(c.difference, -2500);
      expect(c.percent, -25);
    });

    test('is the same when both periods match', () {
      const c = Comparison(current: 10000, previous: 10000);

      expect(c.direction, ChangeDirection.same);
      expect(c.difference, 0);
      expect(c.percent, 0);
    });

    test('has no percent when there was nothing before, but is up', () {
      const c = Comparison(current: 10000, previous: 0);

      expect(c.direction, ChangeDirection.up);
      expect(c.percent, isNull);
    });

    test('is down to nothing when this period has nothing', () {
      const c = Comparison(current: 0, previous: 10000);

      expect(c.direction, ChangeDirection.down);
      expect(c.percent, -100);
    });
  });
}
