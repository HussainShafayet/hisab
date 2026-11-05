/// A short line on a More tile that tells how that part stands, like "2 late"
/// on Loans.
class MoreStatus {
  const MoreStatus(this.kind, this.args, {this.warning = false});

  final MoreStatusKind kind;
  final Map<String, Object> args;

  /// It needs a look: shown in a warning color.
  final bool warning;
}

enum MoreStatusKind {
  loansLate,
  backupNever,
  backupOld,
  backupFresh,
  recurringSoon,
}

/// A backup older than this many days is called out.
const backupOldDays = 14;

/// How the backup stands: never made, old, or recent. [daysSince] is null when
/// none was ever made.
MoreStatus backupStatus(int? daysSince) {
  if (daysSince == null) {
    return const MoreStatus(MoreStatusKind.backupNever, {}, warning: true);
  }
  if (daysSince >= backupOldDays) {
    return MoreStatus(MoreStatusKind.backupOld, {
      'days': daysSince,
    }, warning: true);
  }
  return MoreStatus(MoreStatusKind.backupFresh, {'days': daysSince});
}

/// "N late" for loans, or null when none is late.
MoreStatus? loansStatus(int lateCount) => lateCount <= 0
    ? null
    : MoreStatus(MoreStatusKind.loansLate, {'count': lateCount}, warning: true);

/// The next recurring item, when it comes within [withinDays] days (today
/// counts as 0).
MoreStatus? recurringStatus(int? daysToNext, {int withinDays = 3}) {
  if (daysToNext == null || daysToNext < 0 || daysToNext > withinDays) {
    return null;
  }
  return MoreStatus(MoreStatusKind.recurringSoon, {'days': daysToNext});
}

/// The routes visited last, newest first, kept to [max]. A route visited again
/// moves to the front.
List<String> rememberVisit(List<String> before, String route, {int max = 4}) =>
    [route, ...before.where((r) => r != route)].take(max).toList();

/// The saved list of routes (comma separated) as a list.
List<String> parseRecent(String? saved) => [
  for (final part in (saved ?? '').split(','))
    if (part.startsWith('/')) part,
];
