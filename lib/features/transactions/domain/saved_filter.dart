import 'dart:convert';

import 'package:hishab/features/transactions/domain/feeling.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// The most filters that can be saved, and the longest name.
const maxSavedFilters = 10;
const maxSavedFilterNameLength = 30;

/// A filter the person named, like "Regret over ৳500", to use again. It holds
/// what the filter sheet chooses except the dates and the search text, which
/// belong to the moment.
class SavedFilter {
  const SavedFilter({required this.name, required this.filter});

  final String name;
  final TransactionFilter filter;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': filter.type?.name,
    'categoryId': filter.categoryId,
    'accountId': filter.accountId,
    'minAmount': filter.minAmount,
    'maxAmount': filter.maxAmount,
    'tagId': filter.tagId,
    'feeling': filter.feeling?.name,
  };

  /// Null when [json] is not a saved filter.
  static SavedFilter? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final name = json['name'];
    if (name is! String || name.trim().isEmpty) return null;
    int? whole(String key) {
      final value = json[key];
      return value is int ? value : null;
    }

    return SavedFilter(
      name: name.trim(),
      filter: TransactionFilter(
        type: TransactionType.values.asNameMap()[json['type']],
        categoryId: whole('categoryId'),
        accountId: whole('accountId'),
        minAmount: whole('minAmount'),
        maxAmount: whole('maxAmount'),
        tagId: whole('tagId'),
        feeling: Feeling.values.asNameMap()[json['feeling']],
      ),
    );
  }
}

/// The saved filters in [text], or none when it is missing or damaged.
List<SavedFilter> decodeSavedFilters(String? text) {
  if (text == null || text.isEmpty) return const [];
  try {
    final decoded = jsonDecode(text);
    if (decoded is! List<Object?>) return const [];
    return [for (final item in decoded) ?SavedFilter.fromJson(item)];
  } on FormatException {
    return const [];
  }
}

String encodeSavedFilters(List<SavedFilter> filters) =>
    jsonEncode([for (final f in filters) f.toJson()]);

/// [filters] with [added] in it: one with the same name (ignoring case) is
/// replaced, and the oldest go when there are more than [maxSavedFilters].
List<SavedFilter> withSavedFilter(
  List<SavedFilter> filters,
  SavedFilter added,
) {
  final kept = [
    for (final f in filters)
      if (f.name.toLowerCase() != added.name.toLowerCase()) f,
    added,
  ];
  return kept.length <= maxSavedFilters
      ? kept
      : kept.sublist(kept.length - maxSavedFilters);
}
