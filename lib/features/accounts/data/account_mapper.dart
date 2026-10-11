import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/accounts/domain/account.dart';

extension AccountRowToDomain on AccountRow {
  Account toDomain() => Account(
    id: id,
    name: name,
    type: type,
    openingBalance: openingBalance,
    includeInTotal: includeInTotal,
    isArchived: isArchived,
  );
}
