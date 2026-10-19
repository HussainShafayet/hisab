import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';

/// What a challenge asks for. Saved by name: never rename a value without a
/// migration.
enum ChallengeKind {
  /// Spend nothing (in a category, or at all).
  noSpend,

  /// Spend no more than a limit.
  limit,
}

const maxChallengeTitleLength = 60;

/// The longest a challenge can last, in days.
const maxChallengeDays = 366;

/// A spending challenge: for the days from [startDate] to [endDate] (both
/// included), stay under [limit] taka of spending, in [categoryId] and
/// everything inside it, or in all spending when it is null.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.kind,
    required this.limit,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.categoryId,
  });

  final int id;
  final String title;
  final ChallengeKind kind;

  /// Null for all spending.
  final int? categoryId;

  /// In poisha. Zero for [ChallengeKind.noSpend].
  final int limit;

  /// Days, without a time.
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  /// How many days it lasts.
  int get days => daysBetween(startDate, endDate) + 1;
}

/// Where a challenge stands.
enum ChallengeState {
  /// Starts on a later day.
  upcoming,

  /// Running, and the spending is within the limit so far.
  active,

  /// Over, and the spending stayed within the limit.
  won,

  /// The spending went above the limit, so it is lost (at once, even before
  /// the last day).
  broken,
}

/// A challenge with what has been spent in it.
class ChallengeItem {
  const ChallengeItem({
    required this.challenge,
    required this.spent,
    this.categoryName,
  });

  final Challenge challenge;

  /// In poisha: the expenses in the challenge's days and category. Transfers
  /// and balance adjustments are not spending.
  final int spent;

  /// The name of the category, or null for all spending.
  final String? categoryName;

  ChallengeState stateOn(DateTime today) {
    final day = dateOnly(today);
    if (spent > challenge.limit) return ChallengeState.broken;
    if (day.isBefore(challenge.startDate)) return ChallengeState.upcoming;
    if (day.isAfter(challenge.endDate)) return ChallengeState.won;
    return ChallengeState.active;
  }

  /// In poisha: what may still be spent. Zero once the limit is used up.
  int get remaining => challenge.limit > spent ? challenge.limit - spent : 0;

  /// How much of the limit is used, from 0 to 1. For a no-spend challenge it
  /// is 0 until something is spent, then 1.
  double get fraction {
    if (challenge.limit == 0) return spent > 0 ? 1 : 0;
    return (spent / challenge.limit).clamp(0.0, 1.0);
  }

  /// The day of the challenge [today] is, from 1 to its length.
  int dayNumber(DateTime today) =>
      (daysBetween(challenge.startDate, dateOnly(today)) + 1).clamp(
        1,
        challenge.days,
      );

  /// Days to go, today included, while it runs; zero once it is over.
  int daysLeft(DateTime today) {
    final left = daysBetween(dateOnly(today), challenge.endDate) + 1;
    return left < 0 ? 0 : left;
  }

  /// Days until it starts, or zero once it has.
  int daysUntilStart(DateTime today) {
    final until = daysBetween(dateOnly(today), challenge.startDate);
    return until < 0 ? 0 : until;
  }
}

/// A name for a challenge made of what it asks, which the person may change.
String challengeTitle({
  required ChallengeKind kind,
  required int days,
  required int limit,
  String? categoryName,
}) {
  final args = {
    'category': categoryName,
    'amount': formatPoisha(limit),
    'n': days,
  };
  final one = days == 1;

  if (kind == ChallengeKind.noSpend) {
    if (categoryName == null) {
      return one
          ? tr('No spending for 1 day')
          : tr('No spending for {n} days', args);
    }
    return one
        ? tr('No {category} spending for 1 day', args)
        : tr('No {category} spending for {n} days', args);
  }
  if (categoryName == null) {
    return one
        ? tr('Spend under {amount} in 1 day', args)
        : tr('Spend under {amount} in {n} days', args);
  }
  return one
      ? tr('{category} under {amount} in 1 day', args)
      : tr('{category} under {amount} in {n} days', args);
}
