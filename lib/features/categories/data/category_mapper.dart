import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/categories/domain/category.dart';

extension CategoryRowToDomain on CategoryRow {
  Category toDomain() => Category(
    id: id,
    name: name,
    type: type,
    parentId: parentId,
    icon: icon,
    color: color,
    isArchived: isArchived,
    sortOrder: sortOrder,
  );
}
