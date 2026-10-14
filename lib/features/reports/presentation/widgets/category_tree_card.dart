import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/percent.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/reports/domain/category_branch.dart';

/// Where the money went (or came from), down the category tree: each group
/// shows the total of what is inside it, and opens to show the categories
/// inside, down as far as they go. Bars and percentages are of the whole
/// period.
class CategoryTreeCard extends StatefulWidget {
  const CategoryTreeCard({
    required this.expense,
    required this.income,
    super.key,
  });

  final List<CategoryBranch> expense;
  final List<CategoryBranch> income;

  @override
  State<CategoryTreeCard> createState() => _CategoryTreeCardState();
}

class _CategoryTreeCardState extends State<CategoryTreeCard> {
  var _showIncome = false;

  /// The ids of the groups that are open.
  final Set<int> _open = {};

  List<CategoryBranch> get _branches =>
      _showIncome ? widget.income : widget.expense;

  /// The rows to draw: a closed group hides what is inside it. A group that
  /// has money of its own as well as categories inside gets a row for that
  /// money when it is open.
  List<_Row> _rows() {
    final rows = <_Row>[];
    void walk(List<CategoryBranch> branches, int depth) {
      for (final branch in branches) {
        rows.add(_Row(branch: branch, depth: depth));
        if (_open.contains(branch.category.id) && branch.children.isNotEmpty) {
          if (branch.own > 0) {
            rows.add(_Row(branch: branch, depth: depth + 1, isOwn: true));
          }
          walk(branch.children, depth + 1);
        }
      }
    }

    walk(_branches, 0);
    return rows;
  }

  void _toggle(int id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branches = _branches;
    final grand = branches.fold<int>(0, (sum, b) => sum + b.total);
    final groups = [
      for (final b in flattenBranches(branches))
        if (b.children.isNotEmpty) b.category.id,
    ];
    final allOpen = groups.isNotEmpty && groups.every(_open.contains);

    return Card(
      key: const ValueKey('category-tree-card'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _showIncome
                        ? tr('Where the money came from')
                        : tr('Where the money went'),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (groups.isNotEmpty)
                  TextButton(
                    key: const ValueKey('tree-open-all'),
                    onPressed: () => setState(() {
                      if (allOpen) {
                        _open.clear();
                      } else {
                        _open.addAll(groups);
                      }
                    }),
                    child: Text(allOpen ? tr('Close all') : tr('Open all')),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              key: const ValueKey('tree-type'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(tr('Expense'))),
                ButtonSegment(value: true, label: Text(tr('Income'))),
              ],
              selected: {_showIncome},
              onSelectionChanged: (selection) =>
                  setState(() => _showIncome = selection.first),
            ),
            const SizedBox(height: 8),
            if (branches.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  tr('Nothing recorded for this period.'),
                  key: const ValueKey('tree-empty'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final row in _rows())
                _TreeRow(
                  row: row,
                  grand: grand,
                  isOpen: _open.contains(row.branch.category.id),
                  onToggle: () => _toggle(row.branch.category.id),
                ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row({required this.branch, required this.depth, this.isOwn = false});

  final CategoryBranch branch;
  final int depth;

  /// The row for the money put directly on a group, shown inside it.
  final bool isOwn;
}

class _TreeRow extends StatelessWidget {
  const _TreeRow({
    required this.row,
    required this.grand,
    required this.isOpen,
    required this.onToggle,
  });

  final _Row row;
  final int grand;
  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branch = row.branch;
    final category = branch.category;
    final amount = row.isOwn ? branch.own : branch.total;
    final hasChildren = branch.children.isNotEmpty && !row.isOwn;
    final id = category.id;
    final suffix = row.isOwn ? '-own' : '';
    final color = Color(category.color);

    return InkWell(
      key: ValueKey('tree-row-$id$suffix'),
      onTap: hasChildren ? onToggle : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: EdgeInsets.fromLTRB(row.depth * 16.0, 6, 0, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24,
                  child: hasChildren
                      ? Icon(
                          isOpen ? Icons.expand_more : Icons.chevron_right,
                          key: ValueKey('tree-toggle-$id'),
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        )
                      : null,
                ),
                CategoryAvatar(
                  icon: category.icon,
                  color: category.color,
                  radius: 14,
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Text(
                    row.isOwn
                        ? tr('Directly in {name}', {'name': category.name})
                        : category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                // A long amount shrinks to fit a small phone.
                Expanded(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatPoisha(amount),
                      key: ValueKey('tree-amount-$id$suffix'),
                      style: theme.textTheme.bodyMedium?.tabular.copyWith(
                        fontWeight: row.depth == 0 ? FontWeight.w700 : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: grand == 0 ? 0 : (amount / grand).clamp(0, 1),
                        minHeight: 4,
                        color: color,
                        backgroundColor: color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      formatPercent(amount, grand),
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
