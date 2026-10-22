import 'dart:convert';

import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/goals/domain/festival.dart';

/// Where the festival settings are kept, in the app settings (so a backup
/// holds them).
const festivalSettingsKey = 'festival_settings';

/// What the person changed about the festivals Hishab shows: the ones they
/// hid, and a day they set by hand for the coming one (the days of Eid are a
/// guess until the moon is seen).
class FestivalSettings {
  const FestivalSettings({this.hidden = const {}, this.dates = const {}});

  final Set<Festival> hidden;

  /// The day chosen for a festival. It counts while that day has not passed;
  /// after it, the festival goes back to its own next day.
  final Map<Festival, DateTime> dates;

  FestivalSettings hiding(Festival festival) =>
      FestivalSettings(hidden: {...hidden, festival}, dates: dates);

  FestivalSettings showing(Festival festival) =>
      FestivalSettings(hidden: {...hidden}..remove(festival), dates: dates);

  FestivalSettings showingAll() => FestivalSettings(dates: dates);

  FestivalSettings withDate(Festival festival, DateTime day) =>
      FestivalSettings(
        hidden: hidden,
        dates: {...dates, festival: dateOnly(day)},
      );

  FestivalSettings withoutDate(Festival festival) =>
      FestivalSettings(hidden: hidden, dates: {...dates}..remove(festival));

  bool get isEmpty => hidden.isEmpty && dates.isEmpty;

  String toJson() => jsonEncode({
    'hidden': [for (final festival in hidden) festival.name],
    'dates': {
      for (final entry in dates.entries)
        entry.key.name:
            '${entry.value.year.toString().padLeft(4, '0')}-'
            '${entry.value.month.toString().padLeft(2, '0')}-'
            '${entry.value.day.toString().padLeft(2, '0')}',
    },
  });

  /// Reads what [toJson] wrote. Anything missing, damaged or not understood
  /// (a festival of a newer version, a day that is not a day) is left out.
  static FestivalSettings fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return const FestivalSettings();
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return const FestivalSettings();
    }
    if (decoded is! Map) return const FestivalSettings();

    Festival? festivalOf(Object? name) =>
        Festival.values.where((f) => f.name == name).firstOrNull;

    final hidden = <Festival>{};
    if (decoded['hidden'] case final List list) {
      for (final name in list) {
        final festival = festivalOf(name);
        if (festival != null) hidden.add(festival);
      }
    }
    final dates = <Festival, DateTime>{};
    if (decoded['dates'] case final Map map) {
      for (final entry in map.entries) {
        final festival = festivalOf(entry.key);
        final day = entry.value is String
            ? DateTime.tryParse(entry.value as String)
            : null;
        if (festival != null && day != null) dates[festival] = dateOnly(day);
      }
    }
    return FestivalSettings(hidden: hidden, dates: dates);
  }
}
