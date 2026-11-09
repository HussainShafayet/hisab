import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// Everyday words that tell where a new category goes, for life in
/// Bangladesh. Each row is the path of a default category ("Food > Kacha bazar
/// > Fish") and the words that point to it. The more specific rows come first,
/// because the first row that fits wins.
const _expenseWords = <(String, List<String>)>[
  ('Food > Kacha bazar > Fish', ['fish', 'mach', 'chingri', 'shrimp']),
  ('Food > Kacha bazar > Fish > Hilsa (ilish)', ['ilish', 'hilsa']),
  ('Food > Kacha bazar > Fish > Rui', ['rui']),
  ('Food > Kacha bazar > Fish > Katla', ['katla']),
  ('Food > Kacha bazar > Beef', ['beef', 'gorur']),
  ('Food > Kacha bazar > Mutton', ['mutton', 'khashi', 'lamb']),
  ('Food > Kacha bazar > Chicken', ['chicken', 'murgi', 'broiler']),
  ('Food > Kacha bazar', ['mangsho', 'meat']),
  (
    'Food > Kacha bazar > Vegetables',
    [
      'sobji',
      'shobji',
      'vegetable',
      'vegetables',
      'alu',
      'potato',
      'onion',
      'piyaj',
      'tomato',
      'begun',
    ],
  ),
  (
    'Food > Kacha bazar > Fruits',
    ['fruit', 'fruits', 'mango', 'aam', 'banana', 'apple', 'orange'],
  ),
  ('Food > Kacha bazar > Eggs', ['egg', 'eggs', 'dim']),
  ('Food > Kacha bazar > Milk', ['milk', 'dudh']),
  ('Food > Kacha bazar', ['bazar', 'kacha']),
  ('Food > Groceries > Rice (chal)', ['chal', 'rice']),
  ('Food > Groceries > Dal', ['dal', 'lentil']),
  ('Food > Groceries > Pulses', ['pulses', 'chola', 'motor']),
  ('Food > Groceries > Cooking oil', ['oil', 'soyabean']),
  (
    'Food > Groceries',
    [
      'grocery',
      'groceries',
      'mudi',
      'sugar',
      'salt',
      'flour',
      'atta',
      'spice',
      'spices',
    ],
  ),
  ('Food > Snacks & tea > Fuchka', ['fuchka', 'phuchka']),
  ('Food > Snacks & tea > Chotpoti', ['chotpoti']),
  ('Food > Snacks & tea > Cha (tea stall)', ['cha', 'tea', 'coffee']),
  (
    'Food > Snacks & tea > Sweets (mishti)',
    ['mishti', 'sweet', 'sweets', 'rasgulla', 'sondesh'],
  ),
  ('Food > Snacks & tea > Cake', ['cake', 'pastry']),
  ('Food > Snacks & tea > Bakery', ['bakery', 'bread', 'biscuit']),
  (
    'Food > Snacks & tea',
    ['snack', 'snacks', 'singara', 'samosa', 'jhalmuri', 'chips'],
  ),
  ('Food > Restaurants > Kacchi', ['kacchi']),
  ('Food > Restaurants > Biryani', ['biryani', 'tehari', 'khichuri']),
  ('Food > Restaurants > Burger', ['burger']),
  ('Food > Restaurants > Fast food', ['pizza', 'kfc', 'fastfood']),
  ('Food > Restaurants > Food delivery apps', ['foodpanda', 'delivery']),
  ('Food > Restaurants', ['restaurant', 'dinner', 'khabar', 'dine']),
  (
    'Food > Daily meals',
    ['lunch', 'tiffin', 'iftar', 'sehri', 'breakfast', 'meal'],
  ),
  ('Transport > City travel > CNG', ['cng']),
  ('Transport > City travel > Auto', ['auto']),
  (
    'Transport > City travel > Ride sharing',
    ['uber', 'pathao', 'obhai', 'indrive', 'ride'],
  ),
  ('Transport > City travel > Rickshaw', ['rickshaw']),
  ('Transport > City travel > Bus', ['bus']),
  ('Transport > City travel', ['metro', 'taxi']),
  ('Transport > Long distance > Train', ['train', 'rail']),
  ('Transport > Long distance > Launch', ['launch', 'steamer']),
  ('Transport > Long distance > Ferry', ['ferry']),
  (
    'Transport > Long distance > Air ticket',
    ['flight', 'air', 'plane', 'airline'],
  ),
  ('Transport > Long distance', ['intercity', 'coach']),
  ('Transport > Own vehicle > Fuel', ['petrol', 'octane', 'fuel', 'diesel']),
  ('Transport > Own vehicle > Parking', ['parking']),
  ('Transport > Own vehicle > Toll', ['toll']),
  ('Transport > Own vehicle > Tyre', ['tyre']),
  ('Transport > Own vehicle', ['bike', 'car', 'servicing', 'mechanic']),
  (
    'Bills & utilities > Electricity',
    ['bijli', 'electric', 'electricity', 'current', 'prepaid', 'meter'],
  ),
  ('Bills & utilities > Gas', ['gas', 'cylinder', 'lpg', 'titas']),
  ('Bills & utilities > Water', ['wasa', 'water']),
  ('Bills & utilities > Internet', ['wifi', 'internet', 'broadband']),
  ('Bills & utilities > Mobile', ['recharge', 'data', 'sim', 'postpaid']),
  ('Bills & utilities > TV & cable', ['dish', 'cable', 'tv']),
  ('Bills & utilities', ['bill', 'utility']),
  ('Rent', ['rent', 'bhara']),
  (
    'House help & repairs > Repairs',
    ['plumber', 'electrician', 'carpenter', 'mistri', 'repair', 'repairs'],
  ),
  (
    'House help & repairs',
    ['bua', 'maid', 'cook', 'guard', 'driver', 'service', 'charge'],
  ),
  ('Health > Medicine', ['medicine', 'dawa', 'pharmacy']),
  (
    'Health > Doctor & tests',
    ['doctor', 'test', 'tests', 'xray', 'scan', 'lab'],
  ),
  ('Health > Dental', ['dental', 'dentist', 'teeth']),
  ('Health > Eye care', ['eye', 'glasses', 'optician']),
  ('Health > Surgery', ['surgery']),
  ('Health > Hospital', ['hospital', 'clinic']),
  ('Health', ['health', 'vaccine']),
  ('Education > Tuition & coaching', ['tuition', 'tutor', 'coaching']),
  ('Education > Books', ['book', 'books']),
  ('Education > Stationery', ['stationery', 'pen', 'khata']),
  ('Education > Exam fees', ['exam']),
  ('Education > Admission fees', ['admission']),
  ('Education > Hostel', ['hostel']),
  ('Education > Mess', ['mess']),
  ('Education > Online courses', ['course', 'courses', 'udemy', 'coursera']),
  ('Education > Uniform', ['uniform']),
  ('Education', ['school', 'college', 'university', 'education']),
  ('Shopping > Clothing > Shoes', ['shoe', 'shoes', 'sandal']),
  ('Shopping > Clothing > Bags', ['bag', 'bags']),
  ('Shopping > Clothing > Jewellery', ['jewellery', 'gold ring']),
  ('Shopping > Clothing > Panjabi', ['panjabi']),
  ('Shopping > Clothing > Saree', ['saree']),
  (
    'Shopping > Clothing',
    ['cloth', 'clothes', 'shirt', 'kameez', 'pant', 'dress'],
  ),
  (
    'Shopping > Electronics & mobile',
    [
      'phone',
      'mobile',
      'laptop',
      'computer',
      'electronics',
      'charger',
      'fridge',
      'fan',
      'tv',
    ],
  ),
  ('Shopping > Household', ['utensil', 'utensils', 'curtain', 'bedding']),
  ('Shopping > Furniture', ['furniture', 'sofa', 'bed', 'table']),
  ('Shopping', ['shopping']),
  ('Family & gifts > Gifts > Salami (Eid)', ['salami']),
  ('Family & gifts > Gifts > Gaye holud gift', ['gaye', 'holud']),
  ('Family & gifts > Gifts > Wedding gift', ['wedding']),
  ('Family & gifts > Gifts > Birthday gift', ['birthday']),
  ('Family & gifts > Gifts', ['gift']),
  ('Family & gifts > Wife', ['wife', 'bou']),
  ('Family & gifts > Husband', ['husband']),
  ('Family & gifts > Children', ['child', 'children', 'baby', 'kids']),
  ('Family & gifts > Family events', ['aqiqah', 'khatna', 'milad', 'funeral']),
  (
    'Family & gifts > Monthly support > Parents',
    ['parents', 'baba', 'abbu', 'amma'],
  ),
  ('Family & gifts', ['family']),
  (
    'Festivals',
    [
      'eid',
      'puja',
      'boishakh',
      'pohela',
      'feast',
      'decoration',
      'festival',
      'durga',
      'christmas',
    ],
  ),
  (
    'Entertainment',
    [
      'cinema',
      'movie',
      'tour',
      'hotel',
      'picnic',
      'game',
      'netflix',
      'hoichoi',
      'youtube',
      'spotify',
      'trip',
      'park',
      'concert',
    ],
  ),
  (
    'Personal care',
    [
      'salon',
      'haircut',
      'parlour',
      'parlor',
      'cosmetics',
      'gym',
      'beauty',
      'skincare',
      'perfume',
    ],
  ),
  (
    'Charity & zakat',
    [
      'zakat',
      'fitra',
      'sadaqah',
      'sadaka',
      'mosque',
      'masjid',
      'madrasa',
      'qurbani',
      'hajj',
      'umrah',
      'donation',
      'charity',
    ],
  ),
  (
    'Savings & insurance',
    [
      'dps',
      'insurance',
      'sanchay',
      'sanchaypatra',
      'shomiti',
      'somiti',
      'savings',
      'fdr',
      'premium',
    ],
  ),
  (
    'Fees & charges',
    [
      'charge',
      'bkash',
      'nagad',
      'rocket',
      'tax',
      'passport',
      'nid',
      'licence',
      'license',
      'late',
      'fee',
      'vat',
    ],
  ),
];

const _incomeWords = <(String, List<String>)>[
  ('Salary', ['salary', 'bonus', 'overtime', 'wage', 'basic']),
  ('Tuition income', ['tuition', 'student']),
  ('Rent income', ['rent', 'bhara', 'tenant']),
  ('Remittance (abroad)', ['remittance', 'abroad', 'probashi']),
  ('Farming', ['crop', 'farm', 'dhan', 'paddy', 'harvest', 'jute']),
  ('Pension & allowance', ['pension', 'allowance', 'stipend']),
  ('Profit & maturity', ['profit', 'maturity', 'interest', 'dps', 'fdr']),
  ('Business', ['shop', 'sales', 'sale', 'business', 'customer']),
  ('Gift', ['salami', 'gift']),
  ('Refund', ['refund', 'return']),
  ('Cashback', ['cashback']),
];

String _key(String name) => name.trim().toLowerCase();

bool _hits(List<String> typed, String phrase, String whole) {
  if (phrase.contains(' ')) return whole.contains(phrase);
  for (final word in typed) {
    if (word == phrase) return true;
    if (phrase.length >= 4 && word.startsWith(phrase)) return true;
    if (word.length >= 4 && phrase.startsWith(word)) return true;
  }
  return false;
}

/// The category a new category called [name] probably goes inside, or null
/// when nothing fits. Only a category that exists, is not archived and has the
/// same [type] is suggested; when the exact place is not there, the nearest
/// one above it is (Food, when there is no Kacha bazar). [exceptId] is the
/// category being edited.
///
/// It looks first for the name among the default categories ("Hilsa" is not
/// one, but "Fuchka & chotpoti" goes inside Snacks & tea), then for everyday
/// words ("ilish" goes inside Fish, "bijli" inside Electricity).
Category? suggestParent({
  required String name,
  required CategoryType type,
  required Iterable<Category> all,
  int? exceptId,
  List<DefaultCategory> expense = defaultExpenseCategories,
  List<DefaultCategory> income = defaultIncomeCategories,
}) {
  final whole = _key(name);
  if (whole.length < 3) return null;
  final ofType = all.where((c) => c.type == type).toList();
  // A name that is already used somewhere is not a new category.
  if (ofType.any((c) => _key(c.name) == whole)) return null;

  final byId = {for (final c in ofType) c.id: c};
  final byPath = <String, Category>{};
  for (final c in ofType) {
    if (c.isArchived || c.id == exceptId) continue;
    byPath.putIfAbsent(pathKey(pathOf(c, byId)), () => c);
  }

  /// The deepest category along [names] that exists.
  Category? nearest(List<String> names) {
    for (var length = names.length; length > 0; length--) {
      final found = byPath[pathKey(names.take(length))];
      if (found != null) return found;
    }
    return null;
  }

  final defaults = type == CategoryType.expense ? expense : income;
  for (final entry in flattenDefaults(defaults)) {
    if (_key(entry.name) == whole && entry.parentPath.isNotEmpty) {
      final found = nearest(entry.parentPath);
      if (found != null) return found;
    }
  }

  final words = whole
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final table = type == CategoryType.expense ? _expenseWords : _incomeWords;
  for (final (path, phrases) in table) {
    if (phrases.any((phrase) => _hits(words, phrase, whole))) {
      final found = nearest(path.split(' > '));
      if (found != null) return found;
    }
  }
  return null;
}
