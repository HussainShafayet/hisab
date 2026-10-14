import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/goals/domain/goal.dart';

/// The days people put money aside for.
enum Festival { eidUlFitr, eidUlAdha, pohelaBoishakh }

/// Home shows the coming festival once it is this many days away or less.
const festivalWindowDays = 120;

/// A goal whose day is this close to a festival counts as its fund.
const _sameFestivalDays = 3;

/// The icon of a festival's fund.
const festivalIcon = 'gift';

/// The julian day number of a day of the tabular Islamic calendar.
int _islamicToJdn(int year, int month, int day) =>
    day +
    (29.5 * (month - 1)).ceil() +
    (year - 1) * 354 +
    (3 + 11 * year) ~/ 30 +
    1948439;

DateTime _fromJdn(int jdn) {
  final utc = DateTime.utc(1970).add(Duration(days: jdn - 2440588));
  return DateTime(utc.year, utc.month, utc.day);
}

/// The next [day] of Islamic [month] on or after [today]. The tabular calendar
/// is a calculation, and the real day is when the moon is seen, so it can be
/// a day out (it was for Eid in 2024 and 2026).
DateTime _nextIslamic(int month, int day, DateTime today) {
  final from = dateOnly(today);
  final start = (from.year - 622) * 33 ~/ 32;
  for (var year = start - 1; ; year++) {
    final date = _fromJdn(_islamicToJdn(year, month, day));
    if (!date.isBefore(from)) return date;
  }
}

/// The next day of [festival], today or later. Eid is about, the moon decides.
DateTime nextFestivalDate(Festival festival, DateTime today) {
  final from = dateOnly(today);
  return switch (festival) {
    Festival.eidUlFitr => _nextIslamic(10, 1, from),
    Festival.eidUlAdha => _nextIslamic(12, 10, from),
    Festival.pohelaBoishakh =>
      DateTime(from.year, 4, 14).isBefore(from)
          ? DateTime(from.year + 1, 4, 14)
          : DateTime(from.year, 4, 14),
  };
}

/// Whether the day is only an estimate.
bool isEstimated(Festival festival) => festival != Festival.pohelaBoishakh;

String festivalName(Festival festival) => switch (festival) {
  Festival.eidUlFitr => tr('Eid-ul-Fitr'),
  Festival.eidUlAdha => tr('Eid-ul-Adha (Qurbani)'),
  Festival.pohelaBoishakh => tr('Pohela Boishakh'),
};

/// What to say on the day itself.
String festivalGreeting(Festival festival) => switch (festival) {
  Festival.pohelaBoishakh => tr('Shubho Noboborsho!'),
  _ => tr('Eid Mubarak!'),
};

/// The name given to a new fund for [festival] on [date], like
/// "Eid-ul-Fitr 2027".
String festivalFundName(Festival festival, DateTime date) =>
    '${festivalName(festival)} ${date.year}';

/// A coming festival, and the goal saving for it if there is one.
class UpcomingFestival {
  const UpcomingFestival({
    required this.festival,
    required this.date,
    required this.daysLeft,
    this.fund,
  });

  final Festival festival;
  final DateTime date;

  /// Zero on the day.
  final int daysLeft;

  /// The goal whose day is within three days of the festival.
  final GoalWithSaved? fund;
}

/// Every festival's next day, the nearest first, each with its fund.
List<UpcomingFestival> upcomingFestivals(
  DateTime today,
  Iterable<GoalWithSaved> goals,
) {
  final from = dateOnly(today);
  final list = [
    for (final festival in Festival.values)
      () {
        final date = nextFestivalDate(festival, from);
        final fund = goals.where((g) {
          final day = g.goal.targetDate;
          return day != null &&
              daysBetween(dateOnly(day), date).abs() <= _sameFestivalDays;
        }).firstOrNull;
        return UpcomingFestival(
          festival: festival,
          date: date,
          daysLeft: daysBetween(from, date),
          fund: fund,
        );
      }(),
  ];
  list.sort((a, b) => a.date.compareTo(b.date));
  return list;
}
