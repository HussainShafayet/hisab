import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/features/reports/data/reports_repository.dart';
import 'package:hishab/features/reports/domain/report_data.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.watch(appDatabaseProvider)),
);

/// The report for a period. The range is a record, which compares by value,
/// so asking for the same period twice shares one result. It is calculated
/// again after any change to the data.
final reportProvider = FutureProvider.autoDispose.family<ReportData, DateRange>(
  (ref, range) {
    ref.watch(dataChangesProvider);
    return ref.watch(reportsRepositoryProvider).loadReport(range);
  },
);
