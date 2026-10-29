import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/backup_settings.dart';
import 'package:hishab/features/bazar/data/bazar_repository.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';
import 'package:hishab/features/bazar/data/form_inbox_service.dart';

import '../../../helpers/fake_form_inbox_gateway.dart';
import '../../../helpers/test_database.dart';

final now = DateTime(2026, 10, 25, 10, 30);
const link =
    'https://docs.google.com/spreadsheets/d/e/2PACX-abc/pub?output=csv';

({
  AppDatabase db,
  BazarRepository repo,
  FakeFormInboxGateway gateway,
  FormInboxService service,
})
setUpInbox() {
  final db = createTestDatabase();
  final gateway = FakeFormInboxGateway();
  final repo = BazarRepository(db);
  return (
    db: db,
    repo: repo,
    gateway: gateway,
    service: FormInboxService(db: db, repository: repo, gateway: gateway),
  );
}

Future<List<String>> names(BazarRepository repo) async => [
  for (final item in await repo.items()) item.name,
];

void main() {
  group('FormInboxService', () {
    test('linking can take the answers already in the sheet', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      s.gateway.answer(['Rice', 'Egg']);

      final result = await s.service.link(link, takeExisting: true, now: now);

      expect(result.added, 2);
      expect(await names(s.repo), ['Rice', 'Egg']);
    });

    test('linking can start from the new answers only', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      s.gateway.answer(['Rice', 'Egg']);

      await s.service.link(link, takeExisting: false, now: now);
      s.gateway.answer(['Salt']);
      final result = await s.service.sync(now);

      expect(result.added, 1);
      expect(await names(s.repo), ['Salt']);
    });

    test('an answer comes in once, even when it is bought and gone', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      s.gateway.answer(['Rice']);
      await s.service.link(link, takeExisting: true, now: now);
      await s.repo.clearList();

      final again = await s.service.sync(now);

      expect(again.added, 0);
      expect(await names(s.repo), isEmpty);
    });

    test('the same thing asked for twice comes in twice', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      await s.service.link(link, takeExisting: false, now: now);
      s.gateway.answer(['Egg']);
      await s.service.sync(now);
      s.gateway.answer(['Egg']);
      await s.service.sync(now);

      expect(await names(s.repo), ['Egg', 'Egg']);
    });

    test('takes the quantity and the remembered price', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      await s.repo.savePrice(name: 'Onion', price: 6000);
      s.gateway.csv = 'Timestamp,Item,Quantity\n10/25/2026,Onion,3\n';

      await s.service.link(link, takeExisting: true, now: now);

      final item = (await s.repo.items()).single;
      expect(item.quantity, 3);
      expect(item.price, 6000);
    });

    test('an answer with several things puts each on the list', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      s.gateway.csv = 'Timestamp,Item\n10/25/2026,"Rice\nEgg, Salt"\n';

      final result = await s.service.link(link, takeExisting: true, now: now);

      expect(result.added, 3);
      expect(await names(s.repo), ['Rice', 'Egg', 'Salt']);
      // The row is counted once: the next sync adds nothing.
      expect((await s.service.sync(now)).added, 0);
    });

    test('does nothing while no sheet is linked', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      s.gateway.answer(['Rice']);

      final result = await s.service.sync(now);

      expect(result.added, 0);
      expect(s.gateway.fetched, isEmpty);
    });

    test('refuses a link that is not a published sheet', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);

      await expectLater(
        s.service.link('rice', takeExisting: true, now: now),
        throwsA(isA<ValidationException>()),
      );
      expect(
        FormInboxStatus.fromSettings(await s.db.settingsDao.getAll()).linked,
        isFalse,
      );
    });

    test('keeps the problem when the sheet cannot be read', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      await s.service.link(link, takeExisting: true, now: now);
      s.gateway.failWith = FormInboxProblem.notPublished;

      await s.service.sync(now);

      final status = FormInboxStatus.fromSettings(
        await s.db.settingsDao.getAll(),
      );
      expect(status.problem, FormInboxProblem.notPublished);
      expect(status.detail, 'HTTP test');
      expect(status.linked, isTrue);
    });

    test('keeps the link of the form, and forgets all on unlink', () async {
      final s = setUpInbox();
      addTearDown(s.db.close);
      await s.service.link(
        link,
        formLink: 'https://forms.gle/abc',
        takeExisting: true,
        now: now,
      );
      var status = FormInboxStatus.fromSettings(
        await s.db.settingsDao.getAll(),
      );
      expect(status.formLink, 'https://forms.gle/abc');

      await s.service.unlink();

      status = FormInboxStatus.fromSettings(await s.db.settingsDao.getAll());
      expect(status.linked, isFalse);
      expect(status.formLink, isNull);
    });

    test('the links and the count stay out of a backup', () {
      for (final key in [
        formCsvKey,
        formLinkKey,
        formImportedKey,
        lastFormSyncKey,
        formProblemKey,
        formDetailKey,
      ]) {
        expect(isDeviceSetting(key), isTrue, reason: key);
      }
    });
  });
}
