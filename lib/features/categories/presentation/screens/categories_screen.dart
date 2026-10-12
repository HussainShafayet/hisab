import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/show_archived_chip.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';

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

  /// The categories that are closed. Everything starts open.
  final Set<int> _closed = {};

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
    final tree = buildCategoryTree(
      (categories.value ?? const <Category>[]).where((c) => c.type == _type),
    );
    final parents = _parentIds(tree);
    final allClosed = parents.isNotEmpty && parents.every(_closed.contains);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          if (parents.isNotEmpty)
            IconButton(
              key: const ValueKey('collapse-all'),
              tooltip: allClosed ? 'Open all' : 'Close all',
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
        label: const Text('Add category'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<CategoryType>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: CategoryType.expense,
                  label: Text('Expense'),
                ),
                ButtonSegment(
                  value: CategoryType.income,
                  label: Text('Income'),
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
                        ? 'No expense categories'
                        : 'No income categories',
                    message: 'Add one to start sorting your transactions.',
                    action: FilledButton(
                      onPressed: () =>
                          context.push(AppRoutes.newCategory(type: _type.name)),
                      child: const Text('Add category'),
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
                        isClosed: _closed.contains(row.node.category.id),
                        onToggle: () => _toggle(row.node.category.id),
                      ),
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

enum _CategoryAction { edit, addSub, archive, restore }

class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.category,
    required this.depth,
    required this.childCount,
    required this.isClosed,
    required this.onToggle,
  });

  final Category category;

  /// How many categories this one is inside: 0 for a top-level category.
  final int depth;

  /// How many categories are directly inside this one.
  final int childCount;
  final bool isClosed;
  final VoidCallback onToggle;

  bool get isChild => depth > 0;

  /// One more level must still fit under [maxCategoryDepth].
  bool get canHaveChildren => depth + 2 <= maxCategoryDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = category.isArchived;
    final notes = [
      if (childCount > 0)
        childCount == 1 ? '1 sub-category' : '$childCount sub-categories',
      if (muted) 'Archived',
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
                    tooltip: isClosed ? 'Open' : 'Close',
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
      trailing: PopupMenuButton<_CategoryAction>(
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (context) => [
          const PopupMenuItem(value: _CategoryAction.edit, child: Text('Edit')),
          if (canHaveChildren && !category.isArchived)
            const PopupMenuItem(
              value: _CategoryAction.addSub,
              child: Text('Add sub-category'),
            ),
          if (category.isArchived)
            const PopupMenuItem(
              value: _CategoryAction.restore,
              child: Text('Restore'),
            )
          else
            const PopupMenuItem(
              value: _CategoryAction.archive,
              child: Text('Archive'),
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
      case _CategoryAction.archive:
        await _archive(context, ref);
      case _CategoryAction.restore:
        await _restore(context, ref);
    }
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Archive "${category.name}"?'),
        content: Text(
          isChild
              ? 'It will be hidden when you add transactions. Existing '
                    'transactions keep it, and you can restore it any time.'
              : 'It and everything inside it will be hidden when you add '
                    'transactions. Existing transactions keep them, and you '
                    'can restore them any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final repository = ref.read(categoriesRepositoryProvider);
    await repository.archiveCategory(category.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${category.name} archived'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => repository.restoreCategory(category.id),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(categoriesRepositoryProvider).restoreCategory(category.id);
    } on ValidationException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
