import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';
import 'package:hishab/features/recurring/presentation/providers/recurring_providers.dart';
import 'package:hishab/features/reminders/reminder_sync.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('ZakatSettings', () {
    test('start with the defaults', () {
      final s = ZakatSettings.fromMap(const {});

      expect(s.basis, NisabBasis.silver);
      expect(s.gramPrice, isNull);
      expect(s.otherAssets, 0);
      expect(s.excludedAccountIds, isEmpty);
      expect(s.countOwedToYou, isTrue);
      expect(s.subtractDebts, isTrue);
      expect(s.hasReminder, isFalse);
    });

    test('survive being written and read again', () {
      const s = ZakatSettings(
        basis: NisabBasis.gold,
        gramPrice: 1645485,
        otherAssets: 2500000,
        excludedAccountIds: {3, 1},
        countOwedToYou: false,
        subtractDebts: false,
        remindMonth: 3,
        remindDay: 20,
      );

      final map = {
        for (final e in s.toMap().entries)
          if (e.value != null) e.key: e.value!,
      };
      final read = ZakatSettings.fromMap(map);

      expect(read.basis, NisabBasis.gold);
      expect(read.gramPrice, 1645485);
      expect(read.otherAssets, 2500000);
      expect(read.excludedAccountIds, {1, 3});
      expect(read.countOwedToYou, isFalse);
      expect(read.subtractDebts, isFalse);
      expect(read.remindMonth, 3);
      expect(read.remindDay, 20);
    });

    test('ignore values that cannot be read', () {
      final s = ZakatSettings.fromMap(const {
        'zakat.basis': 'platinum',
        'zakat.gram_price': 'lots',
        'zakat.excluded_accounts': '1,x,,2',
        'zakat.remind_on': '13-40',
      });

      expect(s.basis, NisabBasis.silver);
      expect(s.gramPrice, isNull);
      expect(s.excludedAccountIds, {1, 2});
      expect(s.hasReminder, isFalse);
    });

    test('can change the reminder and the price', () {
      const s = ZakatSettings(gramPrice: 100, remindMonth: 3, remindDay: 20);

      final cleared = s.copyWith(remindOn: () => null, gramPrice: () => null);
      expect(cleared.hasReminder, isFalse);
      expect(cleared.gramPrice, isNull);
      final moved = s.copyWith(remindOn: () => (month: 5, day: 1));
      expect(moved.remindMonth, 5);
      expect(moved.remindDay, 1);
      expect(moved.gramPrice, 100);
    });
  });

  group('ZakatSettingsRepository', () {
    late AppDatabase db;
    late ZakatSettingsRepository repo;

    setUp(() {
      db = createTestDatabase();
      repo = ZakatSettingsRepository(db);
    });
    tearDown(() => db.close());

    test('saves and loads', () async {
      await repo.save(
        const ZakatSettings(
          basis: NisabBasis.gold,
          gramPrice: 5000,
          remindMonth: 1,
          remindDay: 2,
        ),
      );

      final s = await repo.load();

      expect(s.basis, NisabBasis.gold);
      expect(s.gramPrice, 5000);
      expect(s.remindMonth, 1);
    });

    test('forgets what is cleared', () async {
      await repo.save(
        const ZakatSettings(gramPrice: 5000, remindMonth: 1, remindDay: 2),
      );
      await repo.save(const ZakatSettings());

      final s = await repo.load();

      expect(s.gramPrice, isNull);
      expect(s.hasReminder, isFalse);
    });

    test('leaves the other settings alone', () async {
      await db.settingsDao.put('theme', 'dark');

      await repo.save(const ZakatSettings(gramPrice: 5000));

      expect((await db.settingsDao.getAll())['theme'], 'dark');
    });

    test('follows changes', () async {
      final price = repo
          .watch()
          .map((s) => s.gramPrice)
          .firstWhere((p) => p == 777);

      await repo.save(const ZakatSettings(gramPrice: 777));

      expect(await price, 777);
    });
  });

  group('the zakat reminder', () {
    final now = DateTime(2026, 10, 11, 14, 30);

    test('is none without a day', () {
      expect(zakatReminderFor(const ZakatSettings(), now), isEmpty);
    });

    test('is on the next time the day comes, in the morning', () {
      final reminders = zakatReminderFor(
        const ZakatSettings(remindMonth: 3, remindDay: 20),
        now,
      );

      expect(reminders, hasLength(1));
      expect(reminders.single.when, DateTime(2027, 3, 20, reminderHour));
      expect(reminders.single.title, 'Zakat day');
    });

    test('is this year while the day is still to come', () {
      final reminders = zakatReminderFor(
        const ZakatSettings(remindMonth: 12, remindDay: 1),
        now,
      );

      expect(reminders.single.when.year, 2026);
    });
  });
}
