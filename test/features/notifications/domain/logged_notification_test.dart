import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/features/notifications/domain/logged_notification.dart';

final now = DateTime(2026, 10, 11, 14, 30);

LoggedNotification at(int id, DateTime when) => LoggedNotification(
  id: id,
  kind: AlertKind.bill,
  title: 'Title $id',
  body: 'Body $id',
  at: when,
  immediate: false,
);

void main() {
  group('splitNotifications', () {
    test('puts what has shown first, newest on top', () {
      final lists = splitNotifications([
        at(1, DateTime(2026, 10, 9, 9)),
        at(2, DateTime(2026, 10, 11, 9)),
        at(3, DateTime(2026, 10, 10, 9)),
      ], now);

      expect(lists.sent.map((n) => n.id), [2, 3, 1]);
      expect(lists.upcoming, isEmpty);
    });

    test('puts what is still to come second, the soonest on top', () {
      final lists = splitNotifications([
        at(1, DateTime(2026, 10, 14, 9)),
        at(2, DateTime(2026, 10, 12, 9)),
        at(3, DateTime(2026, 10, 13, 9)),
      ], now);

      expect(lists.upcoming.map((n) => n.id), [2, 3, 1]);
      expect(lists.sent, isEmpty);
    });

    test('counts one at exactly now as shown', () {
      final lists = splitNotifications([at(1, now)], now);

      expect(lists.sent.map((n) => n.id), [1]);
      expect(lists.upcoming, isEmpty);
    });

    test('has two empty lists for nothing', () {
      final lists = splitNotifications(const [], now);

      expect(lists.sent, isEmpty);
      expect(lists.upcoming, isEmpty);
    });
  });
}
