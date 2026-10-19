import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/help/domain/guide_content.dart';
import 'package:hishab/features/help/presentation/screens/guide_topic_screen.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

import '../../../helpers/fixtures.dart';
import '../../../helpers/pump_app.dart';

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

Future<void> openGuide(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text('More'),
    ),
  );
  await tester.pumpAndSettle();
  await tapKey(tester, 'more-help');
}

void main() {
  group('More', () {
    testWithDatabase('starts with Help & guide and groups the rest', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('More'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Help & guide'), findsOneWidget);
      for (final heading in ['Money', 'Plans and shopping', 'Faith']) {
        expect(find.text(heading), findsOneWidget, reason: heading);
      }
      // Each row says what it is for.
      expect(find.text('Cash, bKash, bank and cards'), findsOneWidget);
    });
  });

  group('the guide', () {
    testWithDatabase('lists the groups and the topics', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openGuide(tester);

      expect(find.text('Start here'), findsWidgets);
      expect(find.text('The basics'), findsOneWidget);
      expect(find.byKey(const ValueKey('help-topic-start')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-topic-home')), findsOneWidget);
    });

    testWithDatabase('opens a topic with numbered steps', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openGuide(tester);

      await tapKey(tester, 'help-topic-start');

      expect(find.text('Set up in five steps'), findsOneWidget);
      for (final number in ['1', '2', '3', '4', '5']) {
        expect(find.text(number), findsOneWidget, reason: number);
      }
      // Start here has no screen to open.
      expect(find.byKey(const ValueKey('guide-open')), findsNothing);
    });

    testWithDatabase('can open the feature a topic is about', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openGuide(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('help-topic-bazar')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tapKey(tester, 'help-topic-bazar');
      expect(find.text('Open Bazar list'), findsOneWidget);
      await tapKey(tester, 'guide-open');

      expect(find.byKey(const ValueKey('bazar-name')), findsOneWidget);
    });

    testWithDatabase('searches, says when nothing matches, and clears', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);
      await openGuide(tester);

      await tester.enterText(
        find.byKey(const ValueKey('help-search')),
        'zakat',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-topic-zakat')), findsOneWidget);
      expect(find.byKey(const ValueKey('help-topic-home')), findsNothing);
      // Headings of the groups are gone while searching.
      expect(find.text('The basics'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('help-search')), 'qqqq');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-no-match')), findsOneWidget);

      await tapKey(tester, 'help-search-clear');
      expect(find.text('The basics'), findsOneWidget);
    });

    testWithDatabase('is in Bangla when the app is', (tester, db) async {
      useTallScreen(tester);
      await db.settingsDao.put('language', 'bangla');
      await pumpAppWithDatabase(tester, db);
      await openGuide(tester);

      expect(find.text('সাহায্য ও গাইড'), findsOneWidget);
      await tapKey(tester, 'help-topic-start');
      expect(find.text('পাঁচ ধাপে শুরু'), findsOneWidget);
    });

    testWidgets('says so when a page of the guide does not exist', (
      tester,
    ) async {
      setAppLanguage(AppLanguage.english);
      await tester.pumpWidget(
        const MaterialApp(home: GuideTopicScreen(topicId: 'nope')),
      );

      expect(find.byKey(const ValueKey('guide-missing')), findsOneWidget);
    });
  });

  // The ? on a screen opens the topic of that screen.
  group('the help button', () {
    const screens = <(String, String, String)>[
      ('Accounts', 'accounts', 'Your wallets: cash, bKash, bank, cards.'),
      (
        'Loans',
        'loans',
        'Dhar and baki: money you lent and money you borrowed.',
      ),
      (
        'Savings goals',
        'goals',
        'Save for a laptop, a trip or Eid in small steps.',
      ),
      (
        'Investments',
        'investments',
        'Money put into a shop, farm or partnership: is it paying?',
      ),
      (
        'Bazar list',
        'bazar',
        'Plan the shopping, know the cost, then save it as one expense.',
      ),
      (
        'Trips & events',
        'trips',
        'See what a trip, Eid or a wedding cost in all.',
      ),
      (
        'Recurring',
        'recurring',
        'Rent, bills and salary: enter once, never forget.',
      ),
      ('Split a bill', 'split', 'Paid for friends? Record it in one go.'),
      ('Zakat', 'zakat', 'A rough answer to how much zakat is due.'),
      (
        'Gold & silver',
        'metals',
        'Your gold and silver in bhori, ana and roti, valued today.',
      ),
      (
        'Badges',
        'fun',
        'The playful side: a coin mascot, streaks, badges and a story of your month.',
      ),
      (
        'Categories',
        'categories',
        'Where each taka went: food, transport, rent and more.',
      ),
      (
        'Backup & export',
        'backup',
        'Keep your data safe, move it, or open it in a spreadsheet.',
      ),
      (
        'Settings',
        'settings',
        'Language, look, how entries start, and alerts.',
      ),
    ];

    testWithDatabase('is on every screen of More and opens its topic', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      for (final (title, topic, summary) in screens) {
        await openFromMore(tester, title);
        expect(
          find.byKey(ValueKey('help-$topic')),
          findsOneWidget,
          reason: title,
        );
        await tapKey(tester, 'help-$topic');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('guide-summary'))).data,
          summary,
          reason: title,
        );
        // Back to the screen, back to More.
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
      }
    });

    testWithDatabase('is on the main tabs too', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('help-home')), findsOneWidget);
      for (final (tab, topic) in [
        ('Transactions', 'transactions'),
        ('Budget', 'budget'),
        ('Reports', 'reports'),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(tab),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(ValueKey('help-$topic')),
          findsOneWidget,
          reason: tab,
        );
      }
    });

    test('every topic named by a button exists', () {
      for (final (_, topic, _) in screens) {
        expect(guideTopics.map((t) => t.id), contains(topic), reason: topic);
      }
    });
  });

  group('the welcome card on Home', () {
    testWithDatabase('greets someone who has written nothing', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('welcome-card')), findsOneWidget);
      expect(find.text('Welcome to Hishab'), findsOneWidget);
    });

    testWithDatabase('goes away for good with Not now', (tester, db) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      await tapKey(tester, 'welcome-dismiss');

      expect(find.byKey(const ValueKey('welcome-card')), findsNothing);
      expect((await db.settingsDao.getAll())['welcome_dismissed'], 'true');
    });

    testWithDatabase('starts the tour, and then stays away', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      await pumpAppWithDatabase(tester, db);

      await tapKey(tester, 'welcome-tour');

      expect(find.text('Set up in five steps'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('welcome-card')), findsNothing);
    });

    testWithDatabase('is not shown to someone who has entries', (
      tester,
      db,
    ) async {
      useTallScreen(tester);
      final b = await seedBasics(db);
      await addTransaction(
        db,
        type: TransactionType.expense,
        amount: 5000,
        accountId: b.cash,
        categoryId: b.food,
        date: DateTime(2026, 10, 10, 9),
      );
      await pumpAppWithDatabase(tester, db);

      expect(find.byKey(const ValueKey('welcome-card')), findsNothing);
    });
  });
}
