import 'package:drift/drift.dart';

/// Version 18: the default "Kids pocket money" sat straight inside
/// "Family & gifts", next to "Children" instead of inside it. Moves it into
/// "Children" and calls it "Pocket money", like the new defaults. Only touches
/// the default layout: if the person moved or renamed either category, or
/// "Children" already has a "Pocket money", it is left as it is (apart from
/// the move, which keeps its name then). Transactions keep their category id,
/// so nothing else changes.
Future<void> moveKidsPocketMoney(DatabaseConnectionUser db) async {
  final found = await db
      .customSelect(
        'SELECT k.id AS kid, c.id AS children FROM categories f '
        'JOIN categories k ON k.parent_id = f.id '
        "AND k.name = 'Kids pocket money' "
        "JOIN categories c ON c.parent_id = f.id AND c.name = 'Children' "
        "WHERE f.parent_id IS NULL AND f.name = 'Family & gifts' "
        "AND f.type = 'expense' LIMIT 1",
      )
      .getSingleOrNull();
  if (found == null) return;
  final kid = found.read<int>('kid');
  final children = found.read<int>('children');
  final taken = await db
      .customSelect(
        'SELECT 1 FROM categories WHERE parent_id = ? '
        "AND lower(name) = 'pocket money' LIMIT 1",
        variables: [Variable.withInt(children)],
      )
      .getSingleOrNull();
  await db.customStatement(
    'UPDATE categories SET parent_id = ?, name = ? WHERE id = ?',
    [children, taken == null ? 'Pocket money' : 'Kids pocket money', kid],
  );
}
