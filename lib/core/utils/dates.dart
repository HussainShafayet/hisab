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

/// [day] at the clock time of [time]. Used so a back-dated transaction still
/// sorts by when it was entered within its day.
DateTime combineDayWithTime(DateTime day, DateTime time) =>
    DateTime(day.year, day.month, day.day, time.hour, time.minute, time.second);
