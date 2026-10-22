import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/goals/domain/festival.dart';
import 'package:hishab/features/goals/domain/festival_settings.dart';
import 'package:hishab/features/goals/domain/goal.dart';

GoalWithSaved goal(DateTime? day) => GoalWithSaved(
  goal: SavingsGoal(
    id: 1,
    name: 'A goal',
    target: 5000000,
    icon: 'gift',
    createdAt: DateTime(2026, 10, 1),
    targetDate: day,
  ),
  saved: 0,
);

void main() {
  final today = DateTime(2026, 10, 11);

  group('the festival settings', () {
    test('nothing set is empty', () {
      expect(const FestivalSettings().isEmpty, isTrue);
      expect(FestivalSettings.fromJson(null).isEmpty, isTrue);
      expect(FestivalSettings.fromJson('').isEmpty, isTrue);
    });

    test('are read back as they were written', () {
      final settings = const FestivalSettings()
          .hiding(Festival.pohelaBoishakh)
          .withDate(Festival.eidUlFitr, DateTime(2027, 3, 11, 15));

      final back = FestivalSettings.fromJson(settings.toJson());

      expect(back.hidden, {Festival.pohelaBoishakh});
      // Only the day is kept.
      expect(back.dates, {Festival.eidUlFitr: DateTime(2027, 3, 11)});
    });

    test('hiding, showing and showing all', () {
      var settings = const FestivalSettings()
          .hiding(Festival.eidUlFitr)
          .hiding(Festival.eidUlAdha);

      settings = settings.showing(Festival.eidUlFitr);
      expect(settings.hidden, {Festival.eidUlAdha});

      settings = settings.showingAll();
      expect(settings.hidden, isEmpty);
    });

    test('a day can be set and taken back', () {
      var settings = const FestivalSettings().withDate(
        Festival.eidUlAdha,
        DateTime(2027, 5, 18),
      );
      expect(settings.dates[Festival.eidUlAdha], DateTime(2027, 5, 18));

      settings = settings.withoutDate(Festival.eidUlAdha);
      expect(settings.dates, isEmpty);
      expect(settings.isEmpty, isTrue);
    });

    test('showing all keeps the days that were set', () {
      final settings = const FestivalSettings()
          .hiding(Festival.eidUlFitr)
          .withDate(Festival.eidUlAdha, DateTime(2027, 5, 18))
          .showingAll();

      expect(settings.dates, hasLength(1));
    });

    test('damaged text is read as nothing', () {
      expect(FestivalSettings.fromJson('not json').isEmpty, isTrue);
      expect(FestivalSettings.fromJson('[1, 2]').isEmpty, isTrue);
      expect(
        FestivalSettings.fromJson('{"hidden": 3, "dates": 4}').isEmpty,
        isTrue,
      );
    });

    test('what is not understood is left out, the rest is kept', () {
      final settings = FestivalSettings.fromJson(
        '{"hidden": ["eidUlFitr", "diwali", 5],'
        ' "dates": {"eidUlAdha": "2027-05-18", "eidUlFitr": "soon",'
        ' "diwali": "2027-11-01", "pohelaBoishakh": 7}}',
      );

      expect(settings.hidden, {Festival.eidUlFitr});
      expect(settings.dates, {Festival.eidUlAdha: DateTime(2027, 5, 18)});
    });
  });

  group('the coming festivals with the settings', () {
    test('without settings they are as before', () {
      final list = upcomingFestivals(today, const []);

      expect(list.map((f) => f.festival), [
        Festival.eidUlFitr,
        Festival.pohelaBoishakh,
        Festival.eidUlAdha,
      ]);
      expect(list.every((f) => !f.isChosen), isTrue);
    });

    test('a hidden festival is left out, unless asked for', () {
      final settings = const FestivalSettings().hiding(Festival.eidUlFitr);

      final shown = upcomingFestivals(today, const [], settings: settings);
      final all = upcomingFestivals(
        today,
        const [],
        settings: settings,
        includeHidden: true,
      );

      expect(shown.map((f) => f.festival), isNot(contains(Festival.eidUlFitr)));
      expect(all, hasLength(3));
    });

    test('every festival can be hidden', () {
      final settings = const FestivalSettings()
          .hiding(Festival.eidUlFitr)
          .hiding(Festival.eidUlAdha)
          .hiding(Festival.pohelaBoishakh);

      expect(upcomingFestivals(today, const [], settings: settings), isEmpty);
    });

    test('a day set by hand is used, and the usual day is kept', () {
      final settings = const FestivalSettings().withDate(
        Festival.eidUlFitr,
        DateTime(2027, 3, 12),
      );

      final eid = upcomingFestivals(
        today,
        const [],
        settings: settings,
      ).firstWhere((f) => f.festival == Festival.eidUlFitr);

      expect(eid.date, DateTime(2027, 3, 12));
      expect(eid.usualDate, DateTime(2027, 3, 10));
      expect(eid.isChosen, isTrue);
      expect(eid.daysLeft, 152);
    });

    test('a day equal to the usual one is not a chosen one', () {
      final settings = const FestivalSettings().withDate(
        Festival.eidUlFitr,
        DateTime(2027, 3, 10),
      );

      final eid = upcomingFestivals(
        today,
        const [],
        settings: settings,
      ).firstWhere((f) => f.festival == Festival.eidUlFitr);

      expect(eid.isChosen, isFalse);
    });

    test('a day set by hand still counts on the day itself', () {
      final settings = const FestivalSettings().withDate(
        Festival.eidUlFitr,
        DateTime(2027, 3, 11),
      );

      // The calendar's day, 10 March, has passed; the chosen one has not.
      final eid = upcomingFestivals(
        DateTime(2027, 3, 11),
        const [],
        settings: settings,
      ).firstWhere((f) => f.festival == Festival.eidUlFitr);

      expect(eid.date, DateTime(2027, 3, 11));
      expect(eid.daysLeft, 0);
    });

    test('once the chosen day has passed, the next one comes', () {
      final settings = const FestivalSettings().withDate(
        Festival.eidUlFitr,
        DateTime(2027, 3, 11),
      );

      final eid = upcomingFestivals(
        DateTime(2027, 3, 12),
        const [],
        settings: settings,
      ).firstWhere((f) => f.festival == Festival.eidUlFitr);

      expect(eid.date.year, 2028);
      expect(eid.isChosen, isFalse);
    });

    test('a fund is the goal near the day shown', () {
      final settings = const FestivalSettings().withDate(
        Festival.eidUlFitr,
        DateTime(2027, 3, 20),
      );
      // 18 March is within three days of the chosen 20th, but eight from the
      // usual 10th.
      final fund = goal(DateTime(2027, 3, 18));

      final eid = upcomingFestivals(
        today,
        [fund],
        settings: settings,
      ).firstWhere((f) => f.festival == Festival.eidUlFitr);

      expect(eid.fund, isNotNull);
      expect(
        upcomingFestivals(today, [
          fund,
        ]).firstWhere((f) => f.festival == Festival.eidUlFitr).fund,
        isNull,
      );
    });
  });
}
