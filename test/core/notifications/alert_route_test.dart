import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_route.dart';
import 'package:hishab/core/router/app_routes.dart';

void main() {
  group('routeForAlert', () {
    test('sends each kind to the screen it is about', () {
      expect(routeForAlert(AlertKind.bill), AppRoutes.recurring);
      expect(routeForAlert(AlertKind.loan), AppRoutes.debts);
      expect(routeForAlert(AlertKind.daily), AppRoutes.addTransaction);
      expect(routeForAlert(AlertKind.budgetNear), AppRoutes.budget);
      expect(routeForAlert(AlertKind.budgetOver), AppRoutes.budget);
      expect(routeForAlert(AlertKind.habit), AppRoutes.transactions);
      expect(routeForAlert(AlertKind.wrapped), AppRoutes.wrapped());
      expect(routeForAlert(AlertKind.zakat), AppRoutes.zakat);
    });

    test('has a route for every kind', () {
      for (final kind in AlertKind.values) {
        expect(routeForAlert(kind), startsWith('/'), reason: kind.name);
      }
    });
  });
}
