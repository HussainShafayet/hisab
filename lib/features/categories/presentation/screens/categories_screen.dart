import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryType _type = CategoryType.expense;
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider(_showArchived));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: [
          IconButton(
            tooltip: _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(
              _showArchived ? Icons.visibility : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _showArchived = !_showArchived),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
          Expanded(
            child: categories.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: '$error',
                onRetry: () =>
                    ref.invalidate(categoriesProvider(_showArchived)),
              ),
              data: (all) {
                final tree = buildCategoryTree(
                  all.where((c) => c.type == _type),
                );
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
                    for (final row in flattenCategoryTreeWithDepth(tree))
                      _CategoryTile(category: row.category, depth: row.depth),
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
  const _CategoryTile({required this.category, this.depth = 0});

  final Category category;

  /// How many categories this one is inside: 0 for a top-level category.
  final int depth;

  bool get isChild => depth > 0;

  /// One more level must still fit under [maxCategoryDepth].
  bool get canHaveChildren => depth + 2 <= maxCategoryDepth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = category.isArchived;

    return ListTile(
      contentPadding: EdgeInsets.only(
        left: 16.0 + (depth > 0 ? 16 + 20.0 * depth : 0),
        right: 4,
      ),
      leading: CategoryAvatar(
        icon: category.icon,
        color: category.color,
        radius: isChild ? 14 : 20,
      ),
      title: Text(
        category.name,
        style: muted
            ? TextStyle(color: theme.colorScheme.onSurfaceVariant)
            : null,
      ),
      subtitle: muted ? const Text('Archived') : null,
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
