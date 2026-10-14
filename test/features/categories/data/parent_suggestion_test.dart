import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/data/category_pack.dart';
import 'package:hishab/features/categories/data/default_categories.dart';
import 'package:hishab/features/categories/data/parent_suggestion.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_type.dart';

/// The categories of a fresh install, with the names in [skip] left out.
List<Category> fresh({Set<String> skip = const {}}) {
  final result = <Category>[];
  final ids = <String, int>{};
  for (final (type, defaults) in [
    (CategoryType.expense, defaultExpenseCategories),
    (CategoryType.income, defaultIncomeCategories),
  ]) {
    for (final entry in flattenDefaults(defaults)) {
      if (skip.contains(entry.name)) continue;
      final id = result.length + 1;
      ids['${type.name}/${pathKey(entry.path)}'] = id;
      final parent = entry.parentPath.isEmpty
          ? null
          : ids['${type.name}/${pathKey(entry.parentPath)}'];
      result.add(
        Category(
          id: id,
          name: entry.name,
          type: type,
          parentId: parent,
          icon: entry.icon,
          color: entry.color,
          isArchived: false,
          sortOrder: 0,
        ),
      );
    }
  }
  return result;
}

Category plain(
  int id,
  String name, {
  int? parentId,
  CategoryType type = CategoryType.expense,
  bool archived = false,
}) => Category(
  id: id,
  name: name,
  type: type,
  parentId: parentId,
  icon: 'category',
  color: 1,
  isArchived: archived,
  sortOrder: 0,
);

String? suggest(
  String name, {
  List<Category>? all,
  CategoryType type = CategoryType.expense,
  int? exceptId,
}) => suggestParent(
  name: name,
  type: type,
  all: all ?? fresh(),
  exceptId: exceptId,
)?.name;

void main() {
  group('by everyday words, as deep as the tree goes', () {
    test('food words find the right shelf of Food', () {
      expect(suggest('Hilsa fish'), 'Fish');
      expect(suggest('Sobji'), 'Vegetables');
      expect(suggest('Murgi'), 'Meat & chicken');
      expect(suggest('Fuchka masala'), 'Fuchka & chotpoti');
      expect(suggest('Evening cha'), 'Cha & tea stall');
      expect(suggest('Kacchi biryani'), 'Biryani & kacchi');
      expect(suggest('Office lunch'), 'Daily meals');
      expect(suggest('Basmati chal'), 'Rice (chal)');
    });

    test('transport words', () {
      expect(suggest('Rickshaw fare'), 'City travel');
      expect(suggest('Pathao'), 'Ride sharing');
      expect(suggest('CNG to office'), 'CNG & auto');
      expect(suggest('Octane for bike'), 'Fuel');
      expect(suggest('Night train'), 'Train');
      expect(suggest('Bike chain'), 'Own vehicle');
    });

    test('bills, house help and repairs', () {
      expect(suggest('Bijli'), 'Electricity');
      expect(suggest('WASA'), 'Water');
      expect(suggest('Wifi renewal'), 'Internet');
      expect(suggest('Bua'), 'House help & repairs');
      expect(suggest('Plumber visit'), 'Repairs');
    });

    test('health and education', () {
      expect(suggest('Dentist'), 'Dental');
      expect(suggest('Pharmacy'), 'Medicine');
      expect(suggest('Math tutor'), 'Tuition & coaching');
      expect(suggest('Khata & pen'), 'Books & stationery');
    });

    test('family, festivals, charity and savings', () {
      expect(suggest('Salami'), 'Family & gifts');
      expect(suggest('Pohela Boishakh outing'), 'Festivals');
      expect(suggest('Mosque donation'), 'Charity & zakat');
      expect(suggest('Shomiti'), 'Savings & insurance');
    });

    test('a movie ticket is entertainment, not transport', () {
      expect(suggest('Movie ticket'), 'Entertainment');
    });

    test('a word has to match whole, or start with a longer keyword', () {
      // "tea" must not match inside "teacup", "bus" not inside "business".
      expect(suggest('Teacup'), isNull);
      expect(suggest('Business trip gifts'), isNot('City travel'));
    });

    test('income words go inside the income groups', () {
      expect(suggest('Eid bonus', type: CategoryType.income), 'Salary');
      expect(
        suggest('Shop sales today', type: CategoryType.income),
        'Business',
      );
      expect(
        suggest('Crop sale', type: CategoryType.income),
        'Farming & crops',
      );
      expect(suggest('Salami', type: CategoryType.income), 'Gift');
    });
  });

  group('by the default names', () {
    test('a default that is missing goes inside the place it belongs', () {
      final all = fresh(skip: {'Hostel & mess', 'Cook'});

      expect(suggest('Hostel & mess', all: all), 'Education');
      expect(suggest('Cook', all: all), 'House help & repairs');
    });

    test('is not case sensitive', () {
      expect(
        suggest('PRIVATE TUTOR', all: fresh(skip: {'Private tutor'})),
        'Tuition & coaching',
      );
    });
  });

  group('when the exact place is not there', () {
    test('the nearest group above it is suggested', () {
      final onlyFood = [plain(1, 'Food')];

      expect(suggest('Hilsa fish', all: onlyFood), 'Food');
    });

    test('and the nearest one that exists, not the first', () {
      final all = [plain(1, 'Food'), plain(2, 'Kacha bazar', parentId: 1)];

      expect(suggest('Hilsa fish', all: all), 'Kacha bazar');
    });
  });

  group('when nothing is suggested', () {
    test('for a name that fits nowhere or is too short', () {
      expect(suggest('Xyzzy'), isNull);
      expect(suggest('ab'), isNull);
      expect(suggest('  '), isNull);
    });

    test('for a name that is already used, at any level', () {
      expect(suggest('Food'), isNull);
      expect(suggest('fish'), isNull);
      expect(suggest('Fuchka & chotpoti'), isNull);
    });

    test('when no group it could go inside is there', () {
      expect(suggest('Fuchka', all: [plain(1, 'Transport')]), isNull);
    });

    test('when the group is archived', () {
      expect(
        suggest('Fuchka', all: [plain(1, 'Food', archived: true)]),
        isNull,
      );
    });

    test('when the group is the category being edited', () {
      expect(suggest('Fuchka', all: [plain(5, 'Food')], exceptId: 5), isNull);
    });

    test('for the other type of category', () {
      expect(suggest('Bonus', all: [plain(1, 'Salary')]), isNull);
      expect(
        suggest('Bonus', all: [plain(1, 'Salary')], type: CategoryType.income),
        isNull,
      );
      expect(
        suggest(
          'Bonus',
          all: [plain(1, 'Salary', type: CategoryType.income)],
          type: CategoryType.income,
        ),
        'Salary',
      );
    });
  });
}
