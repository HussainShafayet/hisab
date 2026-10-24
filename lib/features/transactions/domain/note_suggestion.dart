import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// A note written on an earlier entry, with what that entry was.
class PastNote {
  const PastNote({
    required this.note,
    required this.type,
    required this.amount,
    this.categoryId,
  });

  final String note;
  final TransactionType type;

  /// In poisha.
  final int amount;
  final int? categoryId;
}

/// Notes from earlier entries of [type] to offer while one is being typed.
///
/// [history] is newest first. The same note written in different cases counts
/// as one; the newest entry with it says which category and amount to offer.
/// What was typed so far is looked for anywhere in a note, notes that start
/// with it first, then the ones written most often. With nothing typed the
/// most often written notes come first. A note equal to what was typed is not
/// offered again.
List<PastNote> suggestNotes(
  List<PastNote> history,
  String typed, {
  required TransactionType type,
  int limit = 4,
}) {
  final query = typed.trim().toLowerCase();
  final groups = <String, ({PastNote latest, int count, int order})>{};
  for (final past in history) {
    if (past.type != type) continue;
    final key = past.note.trim().toLowerCase();
    if (key.isEmpty) continue;
    final group = groups[key];
    groups[key] = (
      latest: group?.latest ?? past,
      count: (group?.count ?? 0) + 1,
      order: group?.order ?? groups.length,
    );
  }

  final matches = [
    for (final entry in groups.entries)
      if (entry.key != query && (query.isEmpty || entry.key.contains(query)))
        (
          starts: query.isNotEmpty && entry.key.startsWith(query),
          group: entry.value,
        ),
  ];
  matches.sort((a, b) {
    if (a.starts != b.starts) return a.starts ? -1 : 1;
    final byCount = b.group.count.compareTo(a.group.count);
    if (byCount != 0) return byCount;
    return a.group.order.compareTo(b.group.order);
  });
  return [for (final match in matches.take(limit)) match.group.latest];
}
