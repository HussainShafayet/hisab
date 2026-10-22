// Date helpers. Everything works in the phone's local time zone, because
// "today" and "this month" are what the user sees on their own calendar.
// Stored timestamps are UTC instants; `DateTime`s read from the database are
// already local.

/// Midnight at the start of [date]'s day.
DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Midnight on the 1st of [date]'s month. The budget month starts on the 1st.
DateTime monthStart(DateTime date) => DateTime(date.year, date.month);

/// `2026-10`: how a month is written in the database (`budgets.month`).
String monthKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}';

/// The number of days in [date]'s month.
int daysInMonth(DateTime date) => DateTime(date.year, date.month + 1, 0).day;

/// The first day of the week that contains [date]. Weeks start on Sunday, as
/// in Bangladesh (pass [firstWeekday] to change it).
DateTime startOfWeek(DateTime date, {int firstWeekday = DateTime.sunday}) {
  final daysSinceStart = (date.weekday - firstWeekday + 7) % 7;
  return DateTime(date.year, date.month, date.day - daysSinceStart);
}

/// The number of calendar days from [from] to [to] (negative if [to] is
/// earlier). Not affected by daylight saving, which changes a day's length.
int daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// The first day of the month that is [delta] months after [month]
/// (negative for earlier months).
DateTime addMonths(DateTime month, int delta) =>
    DateTime(month.year, month.month + delta);

/// A span of time: [start] is included, [end] is not.
typedef DateRange = ({DateTime start, DateTime end});

/// The local range of [date]'s month: [start] is the 1st, [end] is the 1st of
/// the next month.
DateRange monthRange(DateTime date) =>
    (start: monthStart(date), end: addMonths(date, 1));

/// The local range of calendar year [year]: [start] is 1 January, [end] is 1
/// January of the next year.
DateRange yearRange(int year) =>
    (start: DateTime(year), end: DateTime(year + 1));

/// The [count] months that end with [month], oldest first, each as the first
/// day of the month.
List<DateTime> lastMonths(DateTime month, int count) => [
  for (var i = count - 1; i >= 0; i--) addMonths(monthStart(month), -i),
];

/// The period right before [range], to compare with. A whole calendar month
/// is compared with the month before it, a whole calendar year with the year
/// before it; any other range with the same number of days directly before it.
DateRange previousPeriod(DateRange range) {
  final isWholeMonth =
      range.start == monthStart(range.start) &&
      range.end == addMonths(range.start, 1);
  if (isWholeMonth) return monthRange(addMonths(range.start, -1));
  final isWholeYear =
      range.start == DateTime(range.start.year) &&
      range.end == DateTime(range.start.year + 1);
  if (isWholeYear) return yearRange(range.start.year - 1);
  final days = daysBetween(range.start, range.end);
  return (
    start: DateTime(
      range.start.year,
      range.start.month,
      range.start.day - days,
    ),
    end: range.start,
  );
}

/// [day] at the clock time of [time]. Used so a back-dated transaction still
/// sorts by when it was entered within its day.
DateTime combineDayWithTime(DateTime day, DateTime time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute, time.second);
