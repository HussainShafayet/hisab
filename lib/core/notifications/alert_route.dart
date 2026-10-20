import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The screen a notification of [kind] is about: where a tap on it goes.
String routeForAlert(AlertKind kind) => switch (kind) {
  AlertKind.bill => AppRoutes.recurring,
  AlertKind.loan => AppRoutes.debts,
  AlertKind.daily => AppRoutes.addTransaction,
  AlertKind.budgetNear || AlertKind.budgetOver => AppRoutes.budget,
  AlertKind.habit => AppRoutes.transactions,
  AlertKind.wrapped => AppRoutes.wrapped(),
  AlertKind.zakat => AppRoutes.zakat,
};

/// The tabs of the bottom bar, which are gone to, not pushed on top.
const _tabRoutes = {
  AppRoutes.home,
  AppRoutes.transactions,
  AppRoutes.budget,
  AppRoutes.reports,
  AppRoutes.more,
};

/// Opens [route] in [router]: a tab is switched to, any other screen is put
/// on top.
void openRouteWith(GoRouter router, String route) {
  if (_tabRoutes.contains(route)) {
    router.go(route);
  } else {
    router.push(route);
  }
}

/// Opens [route] from a screen.
void openRoute(BuildContext context, String route) =>
    openRouteWith(GoRouter.of(context), route);

/// The screen a notification the person tapped on the phone asks for, until
/// the app opens it. The notification plugin sets it (with the route as the
/// notification's payload), `HishabApp` opens it and clears it.
final pendingNotificationRoute = ValueNotifier<String?>(null);
