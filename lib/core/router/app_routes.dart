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
  static const importCsv = '/more/backup/import-csv';
  static const settings = '/more/settings';
  static const debts = '/more/debts';
  static const tags = '/more/tags';
  static String tag(int id) => '/more/tags/$id';
  static const investments = '/more/investments';
  static const newInvestment = '/more/investments/new';
  static String investment(int id) => '/more/investments/$id';
  static String editInvestment(int id) => '/more/investments/$id/edit';

  static const goals = '/more/goals';
  static const newGoal = '/more/goals/new';
  static String goal(int id) => '/more/goals/$id';
  static String editGoal(int id) => '/more/goals/$id/edit';

  /// A new goal with its name and day filled in, like a festival fund.
  static String newGoalFor({
    required String name,
    required DateTime day,
    String icon = 'gift',
  }) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Uri(
      path: '/more/goals/new',
      queryParameters: {
        'name': name,
        'day': '${day.year}-${two(day.month)}-${two(day.day)}',
        'icon': icon,
      },
    ).toString();
  }

  static const recurring = '/more/recurring';

  static const newRecurring = '/more/recurring/new';
  static String editRecurring(int id) => '/more/recurring/$id';

  static const newDebt = '/more/debts/new';
  static const splitBill = '/more/debts/split';
  static String debt(int id) => '/more/debts/$id';
  static String editDebt(int id) => '/more/debts/$id/edit';

  /// A new loan with the name already filled in.
  static String newDebtFor(String person) =>
      '/more/debts/new?person=${Uri.encodeQueryComponent(person)}';

  /// Every loan with one person.
  static String debtPerson(String name) =>
      '/more/debts/person?name=${Uri.encodeQueryComponent(name)}';

  static const newAccount = '/more/accounts/new';
  static String editAccount(int id) => '/more/accounts/$id';

  /// [type] is a `CategoryType` name (`expense` or `income`). Pass [parentId]
  /// to add a sub-category.
  static String newCategory({String? type, int? parentId}) => Uri(
    path: '/more/categories/new',
    queryParameters: {'type': ?type, 'parent': ?parentId?.toString()},
  ).toString();
  static String editCategory(int id) => '/more/categories/$id';

  // Full-screen, opened above the bottom navigation.
  static const addTransaction = '/add';

  /// Opens the add form pre-filled with a copy of transaction [id].
  static String duplicateTransaction(int id) => '/add?duplicate=$id';

  /// A transfer into a credit card, for [owed] poisha: paying its bill.
  /// [usd] is the dollars still due on it, in US cents.
  static String payCardBill(int cardId, int owed, {int usd = 0}) =>
      '/add?payCard=$cardId&amount=$owed${usd > 0 ? '&usd=$usd' : ''}';

  /// A new transaction that starts with [amount] poisha and [note], like the
  /// total of the bazar list. The form pops `true` once it is saved.
  static String addWithPrefill({required int amount, required String note}) =>
      '/add?prefillAmount=$amount&prefillNote=${Uri.encodeQueryComponent(note)}';

  static const bazar = '/more/bazar';
  static const zakat = '/more/zakat';
  static const metals = '/more/metals';
  static const badges = '/more/badges';

  /// The wrapped of the month that holds [month]; this month's (or the one
  /// just over) when null.
  static String wrapped([DateTime? month]) => month == null
      ? '/more/wrapped'
      : '/more/wrapped?month=${month.year}-${month.month.toString().padLeft(2, '0')}';

  static String editTransaction(int id) => '/transaction/$id';
}
