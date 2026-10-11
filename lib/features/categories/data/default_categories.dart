class DefaultCategory {
  const DefaultCategory(
    this.name, {
    required this.icon,
    required this.color,
    this.children = const [],
  });

  final String name;

  /// Material icon key, resolved to an `IconData` by the UI.
  final String icon;

  /// ARGB value.
  final int color;

  /// Sub-category names. They reuse the parent's icon and color.
  final List<String> children;
}

/// Created once, when the database is first created, in this order (the list
/// position becomes `sort_order`). Edit freely: existing installs are not
/// affected, and every category can be changed or archived in the app.
const defaultExpenseCategories = [
  DefaultCategory(
    'Food',
    icon: 'restaurant',
    color: 0xFFEF5350,
    children: ['Groceries', 'Restaurants', 'Snacks & tea'],
  ),
  DefaultCategory(
    'Transport',
    icon: 'directions_bus',
    color: 0xFF42A5F5,
    children: ['Bus & rickshaw', 'Ride sharing', 'Fuel'],
  ),
  DefaultCategory(
    'Bills & utilities',
    icon: 'receipt_long',
    color: 0xFFFFA726,
    children: ['Electricity', 'Gas', 'Water', 'Internet', 'Mobile recharge'],
  ),
  DefaultCategory('Rent', icon: 'home', color: 0xFF8D6E63),
  DefaultCategory(
    'Health',
    icon: 'local_hospital',
    color: 0xFFEC407A,
    children: ['Medicine', 'Doctor & tests'],
  ),
  DefaultCategory('Education', icon: 'school', color: 0xFF5C6BC0),
  DefaultCategory(
    'Shopping',
    icon: 'shopping_bag',
    color: 0xFFAB47BC,
    children: ['Clothing', 'Household'],
  ),
  DefaultCategory('Family & gifts', icon: 'card_giftcard', color: 0xFFFF7043),
  DefaultCategory('Entertainment', icon: 'movie', color: 0xFF26C6DA),
  DefaultCategory('Personal care', icon: 'spa', color: 0xFF9CCC65),
  DefaultCategory(
    'Charity & zakat',
    icon: 'volunteer_activism',
    color: 0xFF26A69A,
  ),
  DefaultCategory('Fees & charges', icon: 'account_balance', color: 0xFF78909C),
  DefaultCategory('Other', icon: 'more_horiz', color: 0xFF9E9E9E),
];

const defaultIncomeCategories = [
  DefaultCategory('Salary', icon: 'payments', color: 0xFF66BB6A),
  DefaultCategory('Business', icon: 'store', color: 0xFF29B6F6),
  DefaultCategory('Freelance', icon: 'laptop_mac', color: 0xFF7E57C2),
  DefaultCategory('Gift', icon: 'redeem', color: 0xFFFF7043),
  DefaultCategory('Other income', icon: 'more_horiz', color: 0xFF9E9E9E),
];
