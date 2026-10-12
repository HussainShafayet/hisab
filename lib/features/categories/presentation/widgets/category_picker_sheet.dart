import 'package:flutter/material.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';

/// What the user did in the category picker.
sealed class CategoryPick {
  const CategoryPick();
}

/// Chose the category with this id.
class CategoryPicked extends CategoryPick {
  const CategoryPicked(this.id);

  final int id;
}

/// Asked to make a new category.
class CategoryAddRequested extends CategoryPick {
  const CategoryAddRequested();
}

/// Chose "top level", for picking where a category goes.
class CategoryTopLevelChosen extends CategoryPick {
  const CategoryTopLevelChosen();
}

/// Opens the category picker: a sheet with a search field, the categories
/// used most, and all categories as a tree that opens and closes. Returns
/// what the user did, or null when the sheet is dismissed.
///
/// [categories] are the ones that can be chosen, a category followed by what
/// is inside it. [frequentIds] are shown first, as quick picks.
///
/// To choose where a category goes, pass [topLevelLabel] (a first row that
/// means "not inside any category") and set [allowAdd] to false.
Future<CategoryPick?> showCategoryPicker(
  BuildContext context, {
  required String title,
  required List<Category> categories,
  List<int> frequentIds = const [],
  int? selectedId,
  String? topLevelLabel,
  bool allowAdd = true,
}) {
  return showModalBottomSheet<CategoryPick>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      // Lift the sheet above the keyboard while searching.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: CategoryPickerSheet(
          title: title,
          categories: categories,
          frequentIds: frequentIds,
          selectedId: selectedId,
          topLevelLabel: topLevelLabel,
          allowAdd: allowAdd,
        ),
      ),
    ),
  );
}

class CategoryPickerSheet extends StatefulWidget {
  const CategoryPickerSheet({
    required this.title,
    required this.categories,
    this.frequentIds = const [],
    this.selectedId,
    this.topLevelLabel,
    this.allowAdd = true,
    super.key,
  });

  final String title;
  final List<Category> categories;
  final List<int> frequentIds;
  final int? selectedId;

  /// When set, a first row with this text that picks "top level".
  final String? topLevelLabel;

  /// Whether the sheet offers to make a new category.
  final bool allowAdd;

  @override
  State<CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<CategoryPickerSheet> {
  final _search = TextEditingController();
  late final Map<int, Category> _byId = {
    for (final c in widget.categories) c.id: c,
  };
  late final List<CategoryNode> _tree = buildCategoryTree(widget.categories);

  /// The categories that are open. The one chosen before is shown, so the
  /// ones above it start open.
  late final Set<int> _open = _ancestorsOf(widget.selectedId);

  String get _query => _search.text.trim().toLowerCase();

  Set<int> _ancestorsOf(int? id) {
    final result = <int>{};
    var current = id == null ? null : _byId[id];
    while (current != null && result.add(current.id)) {
      final parentId = current.parentId;
      current = parentId == null ? null : _byId[parentId];
    }
    result.remove(id);
    return result;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(Category category) =>
      Navigator.of(context).pop(CategoryPicked(category.id));

  void _requestAdd() => Navigator.of(context).pop(const CategoryAddRequested());

  void _toggle(int id) =>
      setState(() => _open.contains(id) ? _open.remove(id) : _open.add(id));

  /// The rows of the tree as it is now: a category's children only follow it
  /// while it is open.
  List<({CategoryNode node, int depth})> _visibleRows() {
    final rows = <({CategoryNode node, int depth})>[];
    void walk(List<CategoryNode> nodes, int depth) {
      for (final node in nodes) {
        rows.add((node: node, depth: depth));
        if (_open.contains(node.category.id)) walk(node.children, depth + 1);
      }
    }

    walk(_tree, 0);
    return rows;
  }

  String _label(Category category) =>
      category.isArchived ? '${category.name} (archived)' : category.name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query;
    final matches = query.isEmpty
        ? const <Category>[]
        : [
            for (final c in widget.categories)
              if (categoryPathLabel(c, _byId).toLowerCase().contains(query)) c,
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(widget.title, style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('category-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search categories',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(_search.clear),
                    ),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: widget.categories.isEmpty && widget.topLevelLabel == null
              ? _Empty(
                  message: 'There are no categories yet.',
                  onAdd: widget.allowAdd ? _requestAdd : null,
                )
              : query.isNotEmpty
              ? _results(context, matches)
              : _treeList(context),
        ),
        if (widget.allowAdd) ...[
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: ListTile(
              key: const ValueKey('category-add'),
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('New category'),
              onTap: _requestAdd,
            ),
          ),
        ] else
          const SafeArea(top: false, child: SizedBox(height: 8)),
      ],
    );
  }

  Widget _results(BuildContext context, List<Category> matches) {
    if (matches.isEmpty) {
      return _Empty(
        message: 'No category matches "${_search.text.trim()}".',
        onAdd: widget.allowAdd ? _requestAdd : null,
      );
    }
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        for (final category in matches)
          _CategoryRow(
            category: category,
            label: _label(category),
            subtitle: category.parentId == null
                ? null
                : categoryPathNames(category, _byId)
                      .sublist(0, categoryPathNames(category, _byId).length - 1)
                      .join(' › '),
            selected: category.id == widget.selectedId,
            onTap: () => _pick(category),
          ),
      ],
    );
  }

  Widget _treeList(BuildContext context) {
    final theme = Theme.of(context);
    final frequent = [for (final id in widget.frequentIds) ?_byId[id]];
    // Two categories can share a name (Other, in Food and in Transport): the
    // quick picks then show the whole path.
    final nameCount = <String, int>{};
    for (final c in widget.categories) {
      nameCount.update(
        c.name.toLowerCase(),
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (widget.topLevelLabel != null)
          ListTile(
            key: const ValueKey('category-top-level'),
            leading: const Icon(Icons.vertical_align_top),
            title: Text(widget.topLevelLabel!),
            trailing: widget.selectedId == null
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null,
            onTap: () =>
                Navigator.of(context).pop(const CategoryTopLevelChosen()),
          ),
        if (_tree.isEmpty && widget.topLevelLabel != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'There is no other category to put it inside yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (frequent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Frequently used', style: theme.textTheme.labelLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in frequent)
                  ActionChip(
                    key: ValueKey('frequent-${category.id}'),
                    avatar: CategoryAvatar(
                      icon: category.icon,
                      color: category.color,
                      radius: 10,
                    ),
                    label: Text(
                      nameCount[category.name.toLowerCase()]! > 1
                          ? categoryPathLabel(category, _byId)
                          : category.name,
                    ),
                    onPressed: () => _pick(category),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('All categories', style: theme.textTheme.labelLarge),
          ),
        ],
        for (final row in _visibleRows())
          _CategoryRow(
            category: row.node.category,
            label: _label(row.node.category),
            depth: row.depth,
            hasChildren: row.node.children.isNotEmpty,
            expanded: _open.contains(row.node.category.id),
            selected: row.node.category.id == widget.selectedId,
            onTap: () => _pick(row.node.category),
            onToggle: () => _toggle(row.node.category.id),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.label,
    required this.selected,
    required this.onTap,
    this.depth = 0,
    this.hasChildren = false,
    this.expanded = false,
    this.onToggle,
    this.subtitle,
  });

  final Category category;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int depth;
  final bool hasChildren;
  final bool expanded;
  final VoidCallback? onToggle;

  /// The categories this one is inside, shown in search results.
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      key: ValueKey('category-option-${category.id}'),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(4 + 20.0 * depth, 4, 12, 4),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: hasChildren
                  ? IconButton(
                      key: ValueKey('category-expand-${category.id}'),
                      tooltip: expanded ? 'Close' : 'Open',
                      icon: Icon(
                        expanded ? Icons.expand_more : Icons.chevron_right,
                      ),
                      onPressed: onToggle,
                    )
                  : null,
            ),
            CategoryAvatar(
              icon: category.icon,
              color: category.color,
              radius: depth == 0 ? 18 : 15,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : null,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message, required this.onAdd});

  final String message;

  /// Null when the sheet cannot make categories.
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onAdd != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('category-empty-add'),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add category'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
