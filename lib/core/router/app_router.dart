import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/router/app_shell.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/presentation/screens/account_form_screen.dart';
import 'package:hishab/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:hishab/features/backup/presentation/screens/backup_screen.dart';
import 'package:hishab/features/budget/presentation/screens/budget_screen.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/screens/categories_screen.dart';
import 'package:hishab/features/categories/presentation/screens/category_form_screen.dart';
import 'package:hishab/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:hishab/features/reports/presentation/screens/reports_screen.dart';
import 'package:hishab/features/settings/presentation/screens/more_screen.dart';
import 'package:hishab/features/settings/presentation/screens/settings_screen.dart';
import 'package:hishab/features/transactions/presentation/screens/add_transaction_screen.dart';
import 'package:hishab/features/transactions/presentation/screens/transactions_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

int? _idOf(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

class _InvalidIdScreen extends StatelessWidget {
  const _InvalidIdScreen(this.what);

  final String what;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ErrorView(message: 'That is not a valid $what.'),
    );
  }
}

/// The app's [GoRouter], exposed as a Riverpod provider so tests can
/// override it and so it is disposed together with the [ProviderScope].
final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.home,
    routes: [
      // The five bottom-navigation tabs. Each branch has its own back stack.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.budget,
                builder: (context, state) => const BudgetScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (context, state) => const MoreScreen(),
                routes: [
                  // Child paths are relative: 'accounts' => /more/accounts.
                  // These open on the root navigator, so they cover the
                  // bottom bar and the global "Add" button.
                  GoRoute(
                    path: 'accounts',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const AccountsScreen(),
                    routes: [
                      // 'new' comes before ':id' so it is not read as an id.
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => const AccountFormScreen(),
                      ),
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = _idOf(state);
                          return id == null
                              ? const _InvalidIdScreen('account')
                              : AccountFormScreen(accountId: id);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'categories',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CategoriesScreen(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) => CategoryFormScreen(
                          initialType: CategoryType.values
                              .asNameMap()[state.uri.queryParameters['type']],
                          initialParentId: int.tryParse(
                            state.uri.queryParameters['parent'] ?? '',
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ':id',
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final id = _idOf(state);
                          return id == null
                              ? const _InvalidIdScreen('category')
                              : CategoryFormScreen(categoryId: id);
                        },
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'backup',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const BackupScreen(),
                  ),
                  GoRoute(
                    path: 'settings',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const SettingsScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Outside the shell, so it opens full screen above the bottom bar.
      GoRoute(
        path: AppRoutes.addTransaction,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AddTransactionScreen(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
