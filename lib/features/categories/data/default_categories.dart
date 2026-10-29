/// A category in the defaults, with the categories inside it, down as many
/// levels as the app allows (see `maxCategoryDepth`).
class DefaultCategory {
  const DefaultCategory(
    this.name, {
    this.icon,
    this.color,
    this.children = const [],
  });

  final String name;

  /// Material icon key, resolved to an `IconData` by the UI. Null means the
  /// icon of the category it is inside; a top-level one always has its own.
  final String? icon;

  /// ARGB value. Null means the color of the category it is inside; a
  /// top-level one always has its own.
  final int? color;

  /// The categories inside this one.
  final List<DefaultCategory> children;
}

/// One default category with everything worked out: where it sits, and its
/// icon and color (its own, or the ones it inherits).
class DefaultEntry {
  const DefaultEntry({
    required this.path,
    required this.icon,
    required this.color,
  });

  /// The names from the top-level category down to this one.
  final List<String> path;
  final String icon;
  final int color;

  String get name => path.last;

  /// The names of the categories it is inside; empty for a top-level one.
  List<String> get parentPath => path.sublist(0, path.length - 1);
}

/// Every default, parents before the categories inside them.
List<DefaultEntry> flattenDefaults(List<DefaultCategory> roots) {
  final entries = <DefaultEntry>[];
  void walk(DefaultCategory node, List<String> above, String icon, int color) {
    final ownIcon = node.icon ?? icon;
    final ownColor = node.color ?? color;
    final path = [...above, node.name];
    entries.add(DefaultEntry(path: path, icon: ownIcon, color: ownColor));
    for (final child in node.children) {
      walk(child, path, ownIcon, ownColor);
    }
  }

  for (final root in roots) {
    assert(root.icon != null && root.color != null, root.name);
    walk(root, const [], root.icon!, root.color!);
  }
  return entries;
}

/// Everyday life in Bangladesh: kacha bazar, rickshaw, tuition, salami,
/// fitra. The busiest groups (food, transport, bills, shopping...) go down a
/// few levels, like Food > Kacha bazar > Fish. The app creates these when the
/// database is first created, in this order (the list position becomes
/// `sort_order`), and an older install can add the missing ones from the
/// Categories screen. Every category can be changed or archived in the app.
const defaultExpenseCategories = [
  DefaultCategory(
    'Food',
    icon: 'restaurant',
    color: 0xFFEF5350,
    children: [
      DefaultCategory(
        'Groceries',
        icon: 'local_grocery_store',
        children: [
          DefaultCategory('Rice (chal)'),
          DefaultCategory('Dal & pulses'),
          DefaultCategory('Cooking oil'),
          DefaultCategory('Flour, sugar & salt'),
          DefaultCategory('Spices & masala'),
        ],
      ),
      DefaultCategory(
        'Kacha bazar',
        icon: 'shopping_cart',
        children: [
          DefaultCategory('Vegetables'),
          DefaultCategory('Fish'),
          DefaultCategory('Meat & chicken'),
          DefaultCategory('Fruits'),
          DefaultCategory('Eggs & milk'),
        ],
      ),
      DefaultCategory(
        'Restaurants',
        children: [
          DefaultCategory('Biryani & kacchi'),
          DefaultCategory('Fast food & burger'),
          DefaultCategory('Chinese & thai'),
          DefaultCategory('Food delivery apps'),
        ],
      ),
      DefaultCategory(
        'Snacks & tea',
        icon: 'local_cafe',
        children: [
          DefaultCategory('Cha & tea stall', icon: 'local_cafe'),
          DefaultCategory('Fuchka & chotpoti', icon: 'fastfood'),
          DefaultCategory('Street snacks'),
          DefaultCategory('Sweets (mishti)', icon: 'celebration'),
          DefaultCategory('Bakery & cake'),
        ],
      ),
      DefaultCategory(
        'Daily meals',
        children: [
          DefaultCategory('Tiffin & office lunch'),
          DefaultCategory('Iftar & sehri'),
        ],
      ),
    ],
  ),
  DefaultCategory(
    'Transport',
    icon: 'directions_bus',
    color: 0xFF42A5F5,
    children: [
      DefaultCategory(
        'City travel',
        children: [
          DefaultCategory('Bus & rickshaw'),
          DefaultCategory('CNG & auto', icon: 'local_taxi'),
          DefaultCategory(
            'Ride sharing',
            icon: 'local_taxi',
            children: [
              DefaultCategory(
                'Pathao',
                children: [
                  DefaultCategory('Pathao Bike', icon: 'two_wheeler'),
                  DefaultCategory('Pathao Car', icon: 'directions_car'),
                  DefaultCategory('Pathao CNG'),
                ],
              ),
              DefaultCategory(
                'Uber',
                children: [
                  DefaultCategory('Uber Moto', icon: 'two_wheeler'),
                  DefaultCategory('Uber Car', icon: 'directions_car'),
                ],
              ),
              DefaultCategory(
                'Obhai',
                children: [
                  DefaultCategory('Obhai Bike', icon: 'two_wheeler'),
                  DefaultCategory('Obhai Car', icon: 'directions_car'),
                ],
              ),
              DefaultCategory(
                'inDrive',
                children: [
                  DefaultCategory('inDrive Bike', icon: 'two_wheeler'),
                  DefaultCategory('inDrive Car', icon: 'directions_car'),
                  DefaultCategory('inDrive CNG'),
                ],
              ),
            ],
          ),
          DefaultCategory('Metro rail'),
        ],
      ),
      DefaultCategory(
        'Long distance',
        children: [
          DefaultCategory('Intercity bus'),
          DefaultCategory('Train', icon: 'train'),
          DefaultCategory('Launch & ferry'),
          DefaultCategory('Air ticket', icon: 'flight'),
        ],
      ),
      DefaultCategory(
        'Own vehicle',
        icon: 'two_wheeler',
        children: [
          DefaultCategory('Fuel', icon: 'local_gas_station'),
          DefaultCategory('Bike servicing', icon: 'two_wheeler'),
          DefaultCategory('Car servicing'),
          DefaultCategory('Tyre & repairs'),
          DefaultCategory('Parking & toll'),
        ],
      ),
    ],
  ),
  DefaultCategory(
    'Bills & utilities',
    icon: 'receipt_long',
    color: 0xFFFFA726,
    children: [
      DefaultCategory(
        'Electricity',
        icon: 'bolt',
        children: [
          DefaultCategory('Prepaid meter recharge'),
          DefaultCategory('Monthly bill'),
        ],
      ),
      DefaultCategory(
        'Gas',
        icon: 'local_fire_department',
        children: [
          DefaultCategory('Pipeline gas bill'),
          DefaultCategory('Gas cylinder (LPG)'),
        ],
      ),
      DefaultCategory('Water', icon: 'water_drop'),
      DefaultCategory('Internet', icon: 'wifi'),
      DefaultCategory(
        'Mobile',
        icon: 'phone_android',
        children: [
          DefaultCategory('Mobile recharge'),
          DefaultCategory('Mobile data pack'),
          DefaultCategory('Postpaid bill'),
        ],
      ),
      DefaultCategory(
        'TV & cable',
        children: [DefaultCategory('Cable & dish')],
      ),
    ],
  ),
  DefaultCategory('Rent', icon: 'home', color: 0xFF8D6E63),
  DefaultCategory(
    'House help & repairs',
    icon: 'handyman',
    color: 0xFF6D4C41,
    children: [
      DefaultCategory('Maid (bua)'),
      DefaultCategory('Cook'),
      DefaultCategory('Guard & service charge'),
      DefaultCategory(
        'Repairs',
        children: [
          DefaultCategory('Plumber'),
          DefaultCategory('Electrician'),
          DefaultCategory('Carpenter & mistri'),
        ],
      ),
    ],
  ),
  DefaultCategory(
    'Health',
    icon: 'local_hospital',
    color: 0xFFEC407A,
    children: [
      DefaultCategory('Medicine', icon: 'medical_services'),
      DefaultCategory(
        'Doctor & tests',
        children: [
          DefaultCategory('Doctor visit'),
          DefaultCategory('Lab tests'),
          DefaultCategory('X-ray & scans'),
        ],
      ),
      DefaultCategory('Hospital & surgery'),
      DefaultCategory('Dental'),
      DefaultCategory('Eye care', icon: 'spa'),
    ],
  ),
  DefaultCategory(
    'Education',
    icon: 'school',
    color: 0xFF5C6BC0,
    children: [
      DefaultCategory('School & college fees'),
      DefaultCategory(
        'Tuition & coaching',
        children: [
          DefaultCategory('Private tutor'),
          DefaultCategory('Coaching centre'),
        ],
      ),
      DefaultCategory('Books & stationery', icon: 'menu_book'),
      DefaultCategory('Exam & admission fees'),
      DefaultCategory('Uniform', icon: 'checkroom'),
      DefaultCategory('Hostel & mess'),
      DefaultCategory('Online courses'),
    ],
  ),
  DefaultCategory(
    'Shopping',
    icon: 'shopping_bag',
    color: 0xFFAB47BC,
    children: [
      DefaultCategory(
        'Clothing',
        icon: 'checkroom',
        children: [
          DefaultCategory('Shirt & panjabi'),
          DefaultCategory('Saree & women\'s wear'),
          DefaultCategory('Kids wear'),
          DefaultCategory('Shoes & bags'),
        ],
      ),
      DefaultCategory(
        'Household',
        children: [
          DefaultCategory('Kitchen & utensils'),
          DefaultCategory('Cleaning supplies'),
          DefaultCategory('Bedding & curtains'),
        ],
      ),
      DefaultCategory(
        'Electronics & mobile',
        icon: 'phone_android',
        children: [
          DefaultCategory('Mobile & accessories'),
          DefaultCategory('Computer & laptop'),
          DefaultCategory('Home appliances'),
        ],
      ),
      DefaultCategory('Furniture'),
    ],
  ),
  DefaultCategory(
    'Family & gifts',
    icon: 'card_giftcard',
    color: 0xFFFF7043,
    children: [
      DefaultCategory(
        'Support to parents',
        icon: 'volunteer_activism',
        children: [
          DefaultCategory('Monthly money', icon: 'payments'),
          DefaultCategory('Parents\' medicine', icon: 'medical_services'),
          DefaultCategory('Clothes for parents', icon: 'checkroom'),
          DefaultCategory('Visits home', icon: 'directions_bus'),
        ],
      ),
      DefaultCategory(
        'Wife / Husband',
        children: [
          DefaultCategory('Clothes & jewellery', icon: 'checkroom'),
          DefaultCategory('Cosmetics & beauty', icon: 'spa'),
          DefaultCategory('Medicine & doctor', icon: 'medical_services'),
          DefaultCategory('Gifts'),
          DefaultCategory('Pocket money', icon: 'wallet'),
          DefaultCategory('Outings together', icon: 'movie'),
        ],
      ),
      DefaultCategory(
        'Children',
        icon: 'child_care',
        children: [
          DefaultCategory('Baby food & diapers', icon: 'local_grocery_store'),
          DefaultCategory('Clothes & shoes', icon: 'checkroom'),
          DefaultCategory('Toys & games', icon: 'sports_esports'),
          DefaultCategory('Medicine & doctor', icon: 'medical_services'),
          DefaultCategory('Treats & birthdays'),
        ],
      ),
      DefaultCategory(
        'Brothers & sisters',
        children: [
          DefaultCategory('Monthly help', icon: 'payments'),
          DefaultCategory('Gifts'),
          DefaultCategory('Education help', icon: 'school'),
        ],
      ),
      DefaultCategory(
        'In-laws',
        children: [
          DefaultCategory('Monthly help', icon: 'payments'),
          DefaultCategory('Gifts'),
          DefaultCategory('Feast & visits'),
        ],
      ),
      DefaultCategory('Salami (Eid)'),
      DefaultCategory('Wedding & gaye holud gift'),
      DefaultCategory('Birthday gifts'),
      DefaultCategory('Kids pocket money', icon: 'child_care'),
    ],
  ),
  DefaultCategory(
    'Festivals',
    icon: 'celebration',
    color: 0xFFD81B60,
    children: [
      DefaultCategory(
        'Eid shopping',
        icon: 'shopping_bag',
        children: [
          DefaultCategory('Eid clothes'),
          DefaultCategory('Eid feast things'),
        ],
      ),
      DefaultCategory('Pohela Boishakh'),
      DefaultCategory('Puja & other festivals'),
      DefaultCategory('Feast & guests'),
      DefaultCategory('Decoration'),
    ],
  ),
  DefaultCategory(
    'Entertainment',
    icon: 'movie',
    color: 0xFF26C6DA,
    children: [
      DefaultCategory('Cinema & shows'),
      DefaultCategory('Tour & hotel', icon: 'flight'),
      DefaultCategory('Outings & picnic'),
      DefaultCategory('Streaming & subscriptions', icon: 'music_note'),
      DefaultCategory('Games', icon: 'sports_esports'),
    ],
  ),
  DefaultCategory(
    'Personal care',
    icon: 'spa',
    color: 0xFF9CCC65,
    children: [
      DefaultCategory('Haircut & salon'),
      DefaultCategory('Parlour'),
      DefaultCategory('Cosmetics'),
      DefaultCategory('Gym', icon: 'fitness_center'),
    ],
  ),
  DefaultCategory(
    'Charity & zakat',
    icon: 'volunteer_activism',
    color: 0xFF26A69A,
    children: [
      DefaultCategory('Zakat'),
      DefaultCategory('Fitra'),
      DefaultCategory('Sadaqah'),
      DefaultCategory('Mosque & madrasa'),
      DefaultCategory('Qurbani'),
      DefaultCategory('Hajj & umrah'),
    ],
  ),
  DefaultCategory(
    'Savings & insurance',
    icon: 'account_balance',
    color: 0xFF43A047,
    children: [
      DefaultCategory('DPS installment'),
      DefaultCategory('Shomiti (committee)'),
      DefaultCategory('Sanchaypatra'),
      DefaultCategory('Insurance premium', icon: 'receipt_long'),
    ],
  ),
  DefaultCategory(
    'Fees & charges',
    icon: 'account_balance',
    color: 0xFF78909C,
    children: [
      DefaultCategory('bKash & Nagad charge', icon: 'phone_android'),
      DefaultCategory('Bank charge'),
      DefaultCategory('Tax & government fees'),
      DefaultCategory('Passport, NID & licence'),
      DefaultCategory('Late fee'),
    ],
  ),
  DefaultCategory('Other', icon: 'more_horiz', color: 0xFF9E9E9E),
];

const defaultIncomeCategories = [
  DefaultCategory(
    'Salary',
    icon: 'payments',
    color: 0xFF66BB6A,
    children: [
      DefaultCategory('Basic salary'),
      DefaultCategory('Overtime'),
      DefaultCategory('Eid & festival bonus'),
    ],
  ),
  DefaultCategory(
    'Business',
    icon: 'store',
    color: 0xFF29B6F6,
    children: [DefaultCategory('Shop sales'), DefaultCategory('Profit')],
  ),
  DefaultCategory('Freelance', icon: 'laptop_mac', color: 0xFF7E57C2),
  DefaultCategory('Tuition income', icon: 'school', color: 0xFF5C6BC0),
  DefaultCategory('Rent income', icon: 'home', color: 0xFF8D6E63),
  DefaultCategory('Remittance (abroad)', icon: 'flight', color: 0xFF26A69A),
  DefaultCategory('Farming & crops', icon: 'store', color: 0xFF7CB342),
  DefaultCategory(
    'Pension & allowance',
    icon: 'account_balance',
    color: 0xFF78909C,
  ),
  DefaultCategory(
    'Profit & maturity',
    icon: 'trending_up',
    color: 0xFF43A047,
    children: [
      DefaultCategory('Bank profit'),
      DefaultCategory('DPS maturity'),
      DefaultCategory('Sanchaypatra profit'),
    ],
  ),
  DefaultCategory(
    'Gift',
    icon: 'redeem',
    color: 0xFFFF7043,
    children: [
      DefaultCategory('Salami received'),
      DefaultCategory('Wedding & birthday gift'),
    ],
  ),
  DefaultCategory('Refund & cashback', icon: 'wallet', color: 0xFFFFA726),
  DefaultCategory('Other income', icon: 'more_horiz', color: 0xFF9E9E9E),
];
