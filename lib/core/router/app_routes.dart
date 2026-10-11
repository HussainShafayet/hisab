/// Every route path in the app, in one place.
abstract final class AppRoutes {
  // Bottom navigation tabs.
  static const home = '/home';
  static const transactions = '/transactions';
  static const budget = '/budget';
  static const reports = '/reports';
  static const more = '/more';

  // Opened from the "More" tab, full screen above the bottom navigation.
  // Keep in sync with the child routes in app_router.dart (covered by
  // test/app_shell_test.dart).
  static const accounts = '/more/accounts';
  static const categories = '/more/categories';
  static const backup = '/more/backup';
  static const settings = '/more/settings';

  static const newAccount = '/more/accounts/new';
  static String editAccount(int id) => '/more/accounts/$id';

  /// [type] is a `CategoryType` name (`expense` or `income`). Pass [parentId]
  /// to add a sub-category.
  static String newCategory({String? type, int? parentId}) => Uri(
    path: '/more/categories/new',
    queryParameters: {'type': ?type, 'parent': ?parentId?.toString()},
  ).toString();
  static String editCategory(int id) => '/more/categories/$id';

  // Full-screen, opened above the bottom navigation by the global FAB.
  static const addTransaction = '/add';
}
