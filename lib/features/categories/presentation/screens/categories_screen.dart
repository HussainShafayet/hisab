import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/reports/presentation/providers/reports_providers.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/show_archived_chip.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// The categories as a tree: each one can be opened and closed to show or
/// hide what is inside it.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _type = CategoryType.expense;
  bool _showArchived = false;

  /// The categories that are closed. A small tree starts fully open. A big
  /// one (the Bangladesh defaults) starts with the top level open, showing
  /// what is directly inside each group, and the groups inside those closed,
  /// so Food > Kacha bazar > Fish is not one endless list.
  final Set<int> _closed = {};
  var _closedSeeded = false;

  /// A tree with more rows than this starts with its deep groups closed.
  static const _bigTree = 40;

  /// The ids of the groups that start closed: none for a small tree, else every
  /// one with others inside it, below the top level.
  Set<int> _deepGroupIds(List<CategoryNode> tree) {
    final nodes = flattenNodes(tree);
    if (nodes.length <= _bigTree) return {};
    return {
      for (final node in nodes)
        if (node.children.isNotEmpty && node.category.parentId != null)
          node.category.id,
    };
  }

  /// The rows to draw: a closed category hides what is inside it.
  List<({CategoryNode node, int depth})> _visibleRows(List<CategoryNode> tree) {
    final rows = <({CategoryNode node, int depth})>[];
    void walk(List<CategoryNode> nodes, int depth) {
      for (final node in nodes) {
        rows.add((node: node, depth: depth));
        if (!_closed.contains(node.category.id)) walk(node.children, depth + 1);
      }
    }

    walk(tree, 0);
    return rows;
  }

  /// The ids of every category that has others inside it.
  Set<int> _parentIds(List<CategoryNode> tree) => {
    for (final row in flattenNodes(tree))
      if (row.children.isNotEmpty) row.category.id,
  };

  void _toggle(int id) => setState(
    () => _closed.contains(id) ? _closed.remove(id) : _closed.add(id),
  );

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(_showArchived));
    final amounts =
        ref.watch(categoryMonthTotalsProvider).value ?? const <int, int>{};
    final month = ref.read(clockProvider)();
    if (!_closedSeeded && categories.hasValue) {
      _closedSeeded = true;
      _closed.addAll(_deepGroupIds(buildCategoryTree(categories.value!)));
    }
    final tree = buildCategoryTree(
      (categories.value ?? const <Category>[]).where((c) => c.type == _type),
    );
    final parents = _parentIds(tree);
    final allClosed = parents.isNotEmpty && parents.every(_closed.contains);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Categories')),
        actions: [
          const HelpButton('categories'),
          if (parents.isNotEmpty)
            IconButton(
              key: const ValueKey('collapse-all'),
              tooltip: allClosed ? tr('Open all') : tr('Close all'),
              icon: Icon(allClosed ? Icons.unfold_more : Icons.unfold_less),
              onPressed: () => setState(() {
                if (allClosed) {
                  _closed.clear();
                } else {
                  _closed.addAll(parents);
                }
              }),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.newCategory(type: _type.name)),
        icon: const Icon(Icons.add),
        label: Text(tr('Add category')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<CategoryType>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text(tr('Expense')),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text(tr('Income')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: ShowArchivedChip(
              value: _showArchived,
              onChanged: (value) => setState(() => _showArchived = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                tr(
                  'Amounts are for {month}. A group counts everything inside '
                  'it.',
                  {'month': monthLabel(month)},
                ),
                key: const ValueKey('amounts-note'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(categoriesProvider(_showArchived)),
              ),
              data: (_) {
                if (tree.isEmpty) {
                  return EmptyState(
                    icon: Icons.category_outlined,
                    title: _type == CategoryType.expense
                        ? tr('No expense categories')
                        : tr('No income categories'),
                    message: tr('Add one to start sorting your transactions.'),
                    action: FilledButton(
                      onPressed: () =>
                          context.push(AppRoutes.newCategory(type: _type.name)),
                      child: Text(tr('Add category')),
                    ),
                  );
                }
                return ListView(
                  // Room below the last row so the add button never covers it.
                  padding: const EdgeInsets.only(bottom: 96),
                  children: [
                    for (final row in _visibleRows(tree))
                      _CategoryTile(
                        category: row.node.category,
                        depth: row.depth,
                        childCount: row.node.children.length,
                        monthTotal: amounts[row.node.category.id],
                        isClosed: _closed.contains(row.node.category.id),
                        onToggle: () => _toggle(row.node.category.id),
                      ),
                    const _AddDefaultsTile(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Under the list: adds the everyday Bangladesh categories this install does
/// not have yet (kacha bazar, rickshaw, tuition, salami, fitra...). Hidden when
/// nothing is missing.
class _AddDefaultsTile extends ConsumerWidget {
  const _AddDefaultsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missing = ref.watch(missingDefaultCountProvider);
    if (missing == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Card(
      key: const ValueKey('add-defaults'),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('Everyday Bangladesh categories'),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                '{count} more are ready: kacha bazar, rickshaw, tuition, '
                'salami, fitra and more. What you have is not changed.',
                {'count': missing},
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const ValueKey('add-defaults-button'),
                onPressed: () => _add(context, ref, missing),
                child: Text(tr('Add them')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref, int missing) async {
    try {
      final added = await ref
          .read(categoriesRepositoryProvider)
          .addMissingDefaults();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showMessage(tr('{count} categories added', {'count': added}));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showError(describeError(e));
    }
  }
}

enum _CategoryAction { edit, addSub, merge, archive, restore }

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.depth,
    required this.childCount,
    required this.isClosed,
    required this.onToggle,
    this.monthTotal,
  });

  final Category category;

  /// How many categories this one is inside: 0 for a top-level category.
  final int depth;

  /// How many categories are directly inside this one.
  final int childCount;
  final bool isClosed;
  final VoidCallback onToggle;

  /// What this category and everything inside it came to this month, in
  /// poisha. Null or 0 shows nothing.
  final int? monthTotal;

  bool get isChild => depth > 0;

  /// One more level must still fit under [maxCategoryDepth].
  bool get canHaveChildren => depth + 2 <= maxCategoryDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = category.isArchived;
    final notes = [
      if (childCount > 0)
        childCount == 1
            ? tr('1 sub-category')
            : tr('{count} sub-categories', {'count': childCount}),
      if (muted) tr('Archived'),
    ];

    return ListTile(
      contentPadding: EdgeInsets.only(left: 4 + 20.0 * depth, right: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            child: childCount == 0
                ? null
                : IconButton(
                    key: ValueKey('category-toggle-${category.id}'),
                    tooltip: isClosed ? tr('Open') : tr('Close'),
                    icon: Icon(
                      isClosed ? Icons.chevron_right : Icons.expand_more,
                    ),
                    onPressed: onToggle,
                  ),
          ),
          CategoryAvatar(
            icon: category.icon,
            color: category.color,
            radius: isChild ? 15 : 20,
          ),
        ],
      ),
      title: Text(
        category.name,
        style: muted
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: notes.isEmpty ? null : Text(notes.join(' · ')),
      onTap: () => context.push(AppRoutes.editCategory(category.id)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((monthTotal ?? 0) != 0)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 104),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  formatPoisha(monthTotal!),
                  key: ValueKey('category-amount-${category.id}'),
                  style: theme.textTheme.bodyMedium?.tabular.copyWith(
                    fontWeight: depth == 0 ? FontWeight.w700 : null,
                    color: muted ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
              ),
            ),
          PopupMenuButton<_CategoryAction>(
            onSelected: (action) => _onAction(context, ref, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _CategoryAction.edit,
                child: Text(tr('Edit')),
              ),
              if (canHaveChildren && !category.isArchived)
                PopupMenuItem(
                  value: _CategoryAction.addSub,
                  child: Text(tr('Add sub-category')),
                ),
              if (!category.isArchived)
                PopupMenuItem(
                  value: _CategoryAction.merge,
                  child: Text(tr('Merge into…')),
                ),
              if (category.isArchived)
                PopupMenuItem(
                  value: _CategoryAction.restore,
                  child: Text(tr('Restore')),
                )
              else
                PopupMenuItem(
                  value: _CategoryAction.archive,
                  child: Text(tr('Archive')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    _CategoryAction action,
  ) async {
    switch (action) {
      case _CategoryAction.edit:
        await context.push(AppRoutes.editCategory(category.id));
      case _CategoryAction.addSub:
        await context.push(
          AppRoutes.newCategory(
            type: category.type.name,
            parentId: category.id,
          ),
        );
      case _CategoryAction.merge:
        await _merge(context, ref);
      case _CategoryAction.archive:
        await _archive(context, ref);
      case _CategoryAction.restore:
        await _restore(context, ref);
    }
  }

  /// Folds this category into another one of the same type: where it went,
  /// then a question, then everything that used it moves.
  Future<void> _merge(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    if (childCount > 0) {
      messenger.showError(
        tr('"{name}" has sub-categories. Move or merge them first.', {
          'name': category.name,
        }),
      );
      return;
    }
    final repository = ref.read(categoriesRepositoryProvider);
    final all = await repository.getCategories();
    if (!context.mounted) return;
    final byId = {for (final c in all) c.id: c};
    final options = all.where(
      (c) => c.type == category.type && c.id != category.id,
    );
    final pick = await showCategoryPicker(
      context,
      title: tr('Merge "{name}" into', {'name': category.name}),
      categories: flattenCategoryTree(buildCategoryTree(options)),
      allowAdd: false,
    );
    if (pick is! CategoryPicked || !context.mounted) return;
    final into = byId[pick.id];
    if (into == null) return;

    final args = {'from': category.name, 'into': categoryPathLabel(into, byId)};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Merge "{from}" into "{into}"?', args)),
        content: Text(
          tr(
            'Everything that uses "{from}" moves to "{into}": transactions, '
            'budgets, repeating entries and challenges. Then "{from}" is '
            'archived. This cannot be undone here; to go back, restore a '
            'backup.',
            args,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-merge'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Merge')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final result = await repository.mergeCategory(
        category.id,
        intoId: into.id,
      );
      messenger.showMessage(
        tr('{transactions} moved to {name}', {
          'transactions': plural(
            result.transactions,
            '1 transaction',
            '{n} transactions',
          ),
          'name': categoryPathLabel(into, byId),
        }),
      );
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Archive "{name}"?', {'name': category.name})),
        content: Text(
          isChild
              ? tr(
                  'It will be hidden when you add transactions. Existing '
                  'transactions keep it, and you can restore it any time.',
                )
              : tr(
                  'It and everything inside it will be hidden when you add '
                  'transactions. Existing transactions keep them, and you '
                  'can restore them any time.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Archive')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repository = ref.read(categoriesRepositoryProvider);
    await repository.archiveCategory(category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showMessage(
      tr('{name} archived', {'name': category.name}),
      duration: undoDuration,
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.restoreCategory(category.id),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(categoriesRepositoryProvider).restoreCategory(category.id);
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showError(describeError(e));
    }
  }
}
