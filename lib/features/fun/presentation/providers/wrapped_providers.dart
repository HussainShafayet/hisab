import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/fun/data/wrapped_repository.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';

/// The wrapped of a month (any day in it), again after any change to the data.
final wrappedProvider = FutureProvider.autoDispose
    .family<MonthWrapped, DateTime>((ref, month) {
      ref.watch(dataChangesProvider);
      return WrappedRepository(ref.watch(appDatabaseProvider))
          .load(month, ref.read(clockProvider)());
    });
