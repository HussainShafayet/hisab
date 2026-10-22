import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/goals/data/festival_settings_repository.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/festival_settings.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late FestivalSettingsRepository repo;

  setUp(() {
    db = createTestDatabase();
    repo = FestivalSettingsRepository(db);
  });
  tearDown(() => db.close());

  test('starts with nothing set', () async {
    expect((await repo.get()).isEmpty, isTrue);
  });

  test('a festival can be hidden and shown', () async {
    await repo.hide(Festival.pohelaBoishakh);
    expect((await repo.get()).hidden, {Festival.pohelaBoishakh});

    await repo.show(Festival.pohelaBoishakh);
    expect((await repo.get()).hidden, isEmpty);
  });

  test('showing all brings every one back and keeps the days', () async {
    await repo.hide(Festival.eidUlFitr);
    await repo.hide(Festival.eidUlAdha);
    await repo.setDate(Festival.eidUlAdha, DateTime(2027, 5, 18));

    await repo.showAll();

    final settings = await repo.get();
    expect(settings.hidden, isEmpty);
    expect(settings.dates, {Festival.eidUlAdha: DateTime(2027, 5, 18)});
  });

  test('a day can be set and cleared', () async {
    await repo.setDate(Festival.eidUlFitr, DateTime(2027, 3, 11, 9));
    expect((await repo.get()).dates, {
      Festival.eidUlFitr: DateTime(2027, 3, 11),
    });

    await repo.clearDate(Festival.eidUlFitr);
    expect((await repo.get()).dates, isEmpty);
  });

  test('setting nothing leaves no setting behind', () async {
    await repo.hide(Festival.eidUlFitr);
    await repo.show(Festival.eidUlFitr);

    expect((await db.settingsDao.getAll())[festivalSettingsKey], isNull);
  });

  test('the stream follows the changes', () async {
    final seen = <int>[];
    final sub = repo.watch().listen((s) => seen.add(s.hidden.length));
    addTearDown(sub.cancel);
    await pumpEventQueue();

    await repo.hide(Festival.eidUlFitr);
    await pumpEventQueue();

    expect(seen.first, 0);
    expect(seen.last, 1);
  });

  test('a damaged setting is read as nothing', () async {
    await db.settingsDao.put(festivalSettingsKey, '{{{');

    expect((await repo.get()).isEmpty, isTrue);
    await repo.hide(Festival.eidUlAdha);
    expect((await repo.get()).hidden, {Festival.eidUlAdha});
  });
}
