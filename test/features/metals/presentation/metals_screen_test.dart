import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/features/metals/data/metals_repository.dart';
import 'package:hishab/features/metals/domain/metals.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';

import '../../../helpers/fake_rate_service.dart';
import '../../../helpers/pump_app.dart';

Future<void> openMetals(WidgetTester tester) async {
  await tester.tap(find.text('More'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Gold & silver'));
  await tester.pumpAndSettle();
}

String totalText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('metals-total'))).data!;

void main() {
  testWithDatabase('opens from More, empty at first', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);

    expect(find.text('No gold or silver yet'), findsOneWidget);
    expect(totalText(tester), '৳0.00');
  });

  testWithDatabase('adds a piece in bhori and shows what it is worth', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await MetalsRepository(db)
        .savePrices(const GramPrices(gold: 1000000)); // 10,000 taka a gram
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);

    await tester.tap(find.byKey(const ValueKey('metals-add')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('holding-name')),
      'Necklace',
    );
    await tester.enterText(find.byKey(const ValueKey('holding-bhori')), '1');
    await tester.pump();
    expect(find.byKey(const ValueKey('holding-preview')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('holding-save')));
    await tester.pumpAndSettle();

    final pieces = await MetalsRepository(db).holdings();
    expect(pieces.single.name, 'Necklace');
    expect(pieces.single.milligrams, 11664);
    expect(pieces.single.purity, 917);
    expect(find.text('Necklace'), findsOneWidget);
    // 11.664 g of 22K at 10,000 taka a gram.
    expect(totalText(tester), '৳1,06,958.88');
  });

  testWithDatabase('asks for a name and a weight', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);
    await tester.tap(find.byKey(const ValueKey('metals-add')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('holding-save')));
    await tester.pump();
    expect(find.byKey(const ValueKey('holding-error')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('holding-name')), 'Ring');
    await tester.tap(find.byKey(const ValueKey('holding-save')));
    await tester.pump();
    expect(find.text('Enter the weight of the piece.'), findsOneWidget);
    expect(await MetalsRepository(db).holdings(), isEmpty);
  });

  testWithDatabase('says the price is missing when there is none', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await MetalsRepository(db)
        .add(metal: Metal.gold, name: 'Ring', milligrams: 4000, purity: 917);
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);

    expect(find.byKey(const ValueKey('metals-needs-price')), findsOneWidget);
  });

  testWithDatabase('a typed bhori price is kept as a price of a gram', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);

    await tester.enterText(
      find.byKey(const ValueKey('metals-gold-price')),
      '180000',
    );
    await tester.pump();

    final gold = (await MetalsRepository(db).prices()).gold!;
    // A gram price is whole poisha, so the bhori price is off by a few poisha.
    expect(bhoriPriceFromGram(Metal.gold, gold), closeTo(18000000, 6));
  });

  testWithDatabase('fetches today\'s price', (tester, db) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(
      tester,
      db,
      overrides: [
        rateServiceProvider.overrideWithValue(
          FakeRateService(gold: 3110.34768, silver: 31.1034768),
        ),
      ],
    );
    await openMetals(tester);

    await tester.tap(find.byKey(const ValueKey('metals-fetch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('metals-fetched')), findsOneWidget);
    expect((await MetalsRepository(db).prices()).gold, 1200000);
  });

  testWithDatabase('says so when the price cannot be fetched', (
    tester,
    db,
  ) async {
    useTallScreen(tester);
    await pumpAppWithDatabase(
      tester,
      db,
      overrides: [
        rateServiceProvider.overrideWithValue(FakeRateService(fails: true)),
      ],
    );
    await openMetals(tester);

    await tester.tap(find.byKey(const ValueKey('metals-fetch')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('metals-fetch-error')), findsOneWidget);
  });

  testWithDatabase('deletes a piece after asking', (tester, db) async {
    useTallScreen(tester);
    final id = await MetalsRepository(db)
        .add(metal: Metal.gold, name: 'Ring', milligrams: 4000, purity: 917);
    await pumpAppWithDatabase(tester, db);
    await openMetals(tester);

    await tester.tap(find.byKey(ValueKey('piece-$id')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('holding-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('holding-confirm-delete')));
    await tester.pumpAndSettle();

    expect(await MetalsRepository(db).holdings(), isEmpty);
  });

  group('zakat', () {
    Future<void> openZakat(WidgetTester tester) async {
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zakat'));
      await tester.pumpAndSettle();
    }

    testWithDatabase('has no gold switch while there is no gold', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openZakat(tester);

      expect(find.byKey(const ValueKey('zakat-count-metals')), findsNothing);
    });

    testWithDatabase('counts the gold and can leave it out', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final metals = MetalsRepository(db);
      await metals.savePrices(const GramPrices(gold: 1000000));
      await metals.add(
        metal: Metal.gold,
        name: 'Ring',
        milligrams: 10000,
        purity: 1000,
      );
      await pumpAppWithDatabase(tester, db);
      await openZakat(tester);

      // 10 g of pure gold at 10,000 taka a gram.
      String assets() =>
          tester.widget<Text>(find.byKey(const ValueKey('zakat-assets'))).data!;
      expect(assets(), '৳1,00,000.00');

      await tester.tap(find.byKey(const ValueKey('zakat-count-metals')));
      await tester.pumpAndSettle();

      expect((await ZakatSettingsRepository(db).load()).countMetals, isFalse);
      expect(assets(), '৳0.00');
    });
  });
}
