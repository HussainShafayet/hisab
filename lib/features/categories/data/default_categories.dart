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
/// fitra. Two things were done on purpose:
///
/// * Nothing is two things at once. "Bus & rickshaw" is Bus and Rickshaw side
///   by side, so a report can tell them apart.
/// * A thing sits in one place only, by what the money was for. Medicine is in
///   Health, clothes in Shopping, gifts in Family & gifts > Gifts. WHO it was
///   for (wife, children, parents) is a tag, not another copy of the tree.
///
/// The busiest groups go down a few levels, like Food > Kacha bazar > Fish >
/// Hilsa. The app creates these when the database is first created, in this
/// order (the list position becomes `sort_order`), and an older install can add
/// the missing ones from the Categories screen. Every category can be changed
/// or archived in the app.
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
          DefaultCategory('Dal'),
          DefaultCategory('Pulses'),
          DefaultCategory('Cooking oil'),
          DefaultCategory('Flour'),
          DefaultCategory('Sugar'),
          DefaultCategory('Salt'),
          DefaultCategory('Spices (masala)'),
        ],
      ),
      DefaultCategory(
        'Kacha bazar',
        icon: 'shopping_cart',
        children: [
          DefaultCategory('Vegetables'),
          DefaultCategory(
            'Fish',
            children: [
              DefaultCategory('Hilsa (ilish)'),
              DefaultCategory('Rui'),
              DefaultCategory('Katla'),
              DefaultCategory('Small fish'),
            ],
          ),
          DefaultCategory('Beef'),
          DefaultCategory('Mutton'),
          DefaultCategory('Chicken'),
          DefaultCategory('Fruits'),
          DefaultCategory('Eggs'),
          DefaultCategory('Milk'),
        ],
      ),
      DefaultCategory(
        'Restaurants',
        children: [
          DefaultCategory('Biryani'),
          DefaultCategory('Kacchi'),
          DefaultCategory('Fast food'),
          DefaultCategory('Burger'),
          DefaultCategory('Chinese'),
          DefaultCategory('Thai'),
          DefaultCategory('Food delivery apps'),
        ],
      ),
      DefaultCategory(
        'Snacks & tea',
        icon: 'local_cafe',
        children: [
          DefaultCategory('Cha (tea stall)', icon: 'local_cafe'),
          DefaultCategory('Fuchka', icon: 'fastfood'),
          DefaultCategory('Chotpoti', icon: 'fastfood'),
          DefaultCategory('Street snacks'),
          DefaultCategory('Sweets (mishti)', icon: 'celebration'),
          DefaultCategory('Bakery'),
          DefaultCategory('Cake'),
        ],
      ),
      DefaultCategory(
        'Daily meals',
        children: [
          DefaultCategory('Tiffin'),
          DefaultCategory('Office lunch'),
          DefaultCategory('Iftar'),
          DefaultCategory('Sehri'),
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
          DefaultCategory('Bus'),
          DefaultCategory('Rickshaw'),
          DefaultCategory('CNG', icon: 'local_taxi'),
          DefaultCategory('Auto', icon: 'local_taxi'),
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
          DefaultCategory('Launch'),
          DefaultCategory('Ferry'),
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
          DefaultCategory('Tyre'),
          DefaultCategory('Vehicle repairs'),
          DefaultCategory('Parking'),
          DefaultCategory('Toll'),
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
        children: [DefaultCategory('Cable'), DefaultCategory('Dish')],
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
      DefaultCategory('Guard'),
      DefaultCategory('Service charge'),
      DefaultCategory(
        'Repairs',
        children: [
          DefaultCategory('Plumber'),
          DefaultCategory('Electrician'),
          DefaultCategory('Carpenter'),
          DefaultCategory('Mistri'),
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
          DefaultCategory('X-ray'),
          DefaultCategory('Scans'),
        ],
      ),
      DefaultCategory('Hospital'),
      DefaultCategory('Surgery'),
      DefaultCategory('Dental'),
      DefaultCategory('Eye care', icon: 'spa'),
    ],
  ),
  DefaultCategory(
    'Education',
    icon: 'school',
    color: 0xFF5C6BC0,
    children: [
      DefaultCategory('School fees'),
      DefaultCategory('College fees'),
      DefaultCategory(
        'Tuition & coaching',
        children: [
          DefaultCategory('Private tutor'),
          DefaultCategory('Coaching centre'),
        ],
      ),
      DefaultCategory('Books', icon: 'menu_book'),
      DefaultCategory('Stationery', icon: 'menu_book'),
      DefaultCategory('Exam fees'),
      DefaultCategory('Admission fees'),
      DefaultCategory('Uniform', icon: 'checkroom'),
      DefaultCategory('Hostel'),
      DefaultCategory('Mess'),
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
          DefaultCategory('Shirt'),
          DefaultCategory('Panjabi'),
          DefaultCategory('Saree'),
          DefaultCategory('Women\'s wear'),
          DefaultCategory('Kids wear'),
          DefaultCategory('Shoes'),
          DefaultCategory('Bags'),
          DefaultCategory('Jewellery', icon: 'redeem'),
        ],
      ),
      DefaultCategory(
        'Household',
        children: [
          DefaultCategory('Kitchen items'),
          DefaultCategory('Utensils'),
          DefaultCategory('Cleaning supplies'),
          DefaultCategory('Bedding'),
          DefaultCategory('Curtains'),
        ],
      ),
      DefaultCategory(
        'Electronics & mobile',
        icon: 'phone_android',
        children: [
          DefaultCategory('Mobile phone'),
          DefaultCategory('Accessories'),
          DefaultCategory('Computer'),
          DefaultCategory('Laptop'),
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
        'Monthly support',
        icon: 'volunteer_activism',
        children: [
          DefaultCategory('Parents', icon: 'payments'),
          DefaultCategory('Siblings', icon: 'payments'),
          DefaultCategory('In-laws', icon: 'payments'),
          DefaultCategory('Relatives', icon: 'payments'),
        ],
      ),
      DefaultCategory('Education help', icon: 'school'),
      DefaultCategory('Visits home', icon: 'directions_bus'),
      // One group for each person of the house, holding what is spent on that
      // person. The same name (Clothes, Gifts) inside two of them is on
      // purpose: the path tells them apart.
      DefaultCategory(
        'Wife',
        icon: 'spa',
        children: [
          DefaultCategory('Pocket money', icon: 'wallet'),
          DefaultCategory('Clothes', icon: 'checkroom'),
          DefaultCategory('Jewellery', icon: 'redeem'),
          DefaultCategory('Cosmetics'),
          DefaultCategory('Parlour'),
          DefaultCategory('Medicine', icon: 'medical_services'),
          DefaultCategory('Doctor', icon: 'local_hospital'),
          DefaultCategory('Pregnancy checkup'),
          DefaultCategory('Delivery'),
          DefaultCategory('Gifts', icon: 'card_giftcard'),
          DefaultCategory('Outings'),
        ],
      ),
      DefaultCategory(
        'Husband',
        icon: 'work',
        children: [
          DefaultCategory('Pocket money', icon: 'wallet'),
          DefaultCategory('Clothes', icon: 'checkroom'),
          DefaultCategory('Medicine', icon: 'medical_services'),
          DefaultCategory('Doctor', icon: 'local_hospital'),
          DefaultCategory('Gifts', icon: 'card_giftcard'),
          DefaultCategory('Outings'),
        ],
      ),
      DefaultCategory(
        'Children',
        icon: 'child_care',
        children: [
          DefaultCategory('Pocket money', icon: 'wallet'),
          DefaultCategory('Baby food', icon: 'local_grocery_store'),
          DefaultCategory('Diapers'),
          DefaultCategory('Toys', icon: 'sports_esports'),
          DefaultCategory('Treats'),
          DefaultCategory('Clothes', icon: 'checkroom'),
          DefaultCategory('Medicine', icon: 'medical_services'),
          DefaultCategory('Doctor', icon: 'local_hospital'),
          DefaultCategory('Vaccine'),
          DefaultCategory('Birthday party'),
          DefaultCategory('Gifts', icon: 'card_giftcard'),
          DefaultCategory('Outings'),
        ],
      ),
      DefaultCategory(
        'Family events',
        icon: 'celebration',
        children: [
          DefaultCategory('Aqiqah'),
          DefaultCategory('Khatna'),
          DefaultCategory('Wedding'),
          DefaultCategory('Milad'),
          DefaultCategory('Funeral'),
        ],
      ),
      DefaultCategory(
        'Gifts',
        icon: 'card_giftcard',
        children: [
          DefaultCategory('Salami (Eid)'),
          DefaultCategory('Eid gift'),
          DefaultCategory('Birthday gift'),
          DefaultCategory('Wedding gift'),
          DefaultCategory('Gaye holud gift'),
          DefaultCategory('Anniversary gift'),
          DefaultCategory('Other gifts'),
        ],
      ),
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
      DefaultCategory('Puja'),
      DefaultCategory('Other festivals'),
      DefaultCategory('Feast'),
      DefaultCategory('Guests'),
      DefaultCategory('Decoration'),
    ],
  ),
  DefaultCategory(
    'Entertainment',
    icon: 'movie',
    color: 0xFF26C6DA,
    children: [
      DefaultCategory('Cinema'),
      DefaultCategory('Shows'),
      DefaultCategory('Tour', icon: 'flight'),
      DefaultCategory('Hotel', icon: 'flight'),
      DefaultCategory('Outings'),
      DefaultCategory('Picnic'),
      DefaultCategory('Streaming', icon: 'music_note'),
      DefaultCategory('Subscriptions', icon: 'music_note'),
      DefaultCategory('Games', icon: 'sports_esports'),
    ],
  ),
  DefaultCategory(
    'Personal care',
    icon: 'spa',
    color: 0xFF9CCC65,
    children: [
      DefaultCategory('Haircut'),
      DefaultCategory('Salon'),
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
      DefaultCategory('Mosque'),
      DefaultCategory('Madrasa'),
      DefaultCategory('Qurbani'),
      DefaultCategory('Hajj'),
      DefaultCategory('Umrah'),
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
      DefaultCategory('bKash charge', icon: 'phone_android'),
      DefaultCategory('Nagad charge', icon: 'phone_android'),
      DefaultCategory('Bank charge'),
      DefaultCategory('Tax'),
      DefaultCategory('Government fees'),
      DefaultCategory('Passport'),
      DefaultCategory('NID'),
      DefaultCategory('Driving licence'),
      DefaultCategory('Late fee'),
      DefaultCategory('Card annual fee'),
      DefaultCategory('Card interest'),
      DefaultCategory('Over-limit fee'),
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
      DefaultCategory('Eid bonus'),
      DefaultCategory('Festival bonus'),
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
  DefaultCategory(
    'Farming',
    icon: 'store',
    color: 0xFF7CB342,
    children: [DefaultCategory('Crops'), DefaultCategory('Livestock')],
  ),
  DefaultCategory(
    'Pension & allowance',
    icon: 'account_balance',
    color: 0xFF78909C,
    children: [DefaultCategory('Pension'), DefaultCategory('Allowance')],
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
      DefaultCategory('Wedding gift received'),
      DefaultCategory('Birthday gift received'),
    ],
  ),
  DefaultCategory('Refund', icon: 'wallet', color: 0xFFFFA726),
  DefaultCategory('Cashback', icon: 'wallet', color: 0xFFFFA726),
  DefaultCategory('Other income', icon: 'more_horiz', color: 0xFF9E9E9E),
];
