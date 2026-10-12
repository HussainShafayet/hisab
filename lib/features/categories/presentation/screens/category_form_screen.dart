import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/categories/data/categories_repository.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/category_style.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';

/// Creates a category, or edits the one with [categoryId]. When creating,
/// [initialType] and [initialParentId] pre-fill the form (used by
/// "Add sub-category").
class CategoryFormScreen extends ConsumerWidget {
  const CategoryFormScreen({
    this.categoryId,
    this.initialType,
    this.initialParentId,
    super.key,
  });

  final int? categoryId;
  final CategoryType? initialType;
  final int? initialParentId;

  bool get _isEditing => categoryId != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = Text(_isEditing ? 'Edit category' : 'New category');

    // Archived categories are included so we can tell whether a category has
    // sub-categories and find a parent that was archived later.
    return ref
        .watch(categoriesProvider(true))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: title),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: title),
            body: ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(categoriesProvider(true)),
            ),
          ),
          data: (all) {
            Category? find(int? id) {
              for (final category in all) {
                if (category.id == id) return category;
              }
              return null;
            }

            final initial = find(categoryId);
            if (_isEditing && initial == null) {
              return Scaffold(
                appBar: AppBar(title: title),
                body: const ErrorView(
                  message: 'This category no longer exists.',
                ),
              );
            }
            return _CategoryForm(
              all: all,
              initial: initial,
              presetParent: find(initialParentId),
              presetType: initialType,
            );
          },
        );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({
    required this.all,
    this.initial,
    this.presetParent,
    this.presetType,
  });

  /// Every category, archived ones included.
  final List<Category> all;

  /// The category being edited, or null when creating.
  final Category? initial;

  /// Parent chosen by "Add sub-category", when creating.
  final Category? presetParent;
  final CategoryType? presetType;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late CategoryType _type =
      widget.initial?.type ??
      widget.presetParent?.type ??
      widget.presetType ??
      CategoryType.expense;
  late int? _parentId = widget.initial != null
      ? widget.initial!.parentId
      : widget.presetParent?.id;
  late String _icon =
      widget.initial?.icon ?? widget.presetParent?.icon ?? 'category';
  late int _color =
      widget.initial?.color ??
      widget.presetParent?.color ??
      defaultCategoryColor;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  late final Map<int, Category> _byId = {for (final c in widget.all) c.id: c};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = ref.read(categoriesRepositoryProvider);
    try {
      // A new category's id goes back to whoever opened the form, so a
      // transaction being entered can pick it right away.
      int? createdId;
      if (_isEditing) {
        await repository.updateCategory(
          widget.initial!.id,
          name: _name.text,
          parentId: _parentId,
          icon: _icon,
          color: _color,
        );
      } else {
        createdId = await repository.createCategory(
          name: _name.text,
          type: _type,
          parentId: _parentId,
          icon: _icon,
          color: _color,
        );
      }
      if (mounted) context.pop(createdId);
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  /// Categories of the chosen type this one can go inside, in tree order:
  /// not itself or anything inside it, nothing archived, nothing that would
  /// make the tree too deep. The current parent stays on the list even if it
  /// has been archived since.
  List<Category> get _parentOptions {
    final ofType = widget.all.where((c) => c.type == _type);
    return [
      for (final c in flattenCategoryTree(buildCategoryTree(ofType)))
        if (c.id == _parentId ||
            categoryParentProblem(
                  all: widget.all,
                  type: _type,
                  parentId: c.id,
                  categoryId: widget.initial?.id,
                ) ==
                null)
          c,
    ];
  }

  /// Opens the sheet to choose which category this one goes inside.
  Future<void> _chooseParent() async {
    final pick = await showCategoryPicker(
      context,
      title: 'Put it inside',
      categories: _parentOptions,
      selectedId: _parentId,
      topLevelLabel: 'Top level (not inside another)',
      allowAdd: false,
    );
    if (!mounted) return;
    switch (pick) {
      case CategoryPicked(:final id):
        setState(() => _parentId = id);
      case CategoryTopLevelChosen():
        setState(() => _parentId = null);
      case CategoryAddRequested() || null:
        break;
    }
  }

  String get _parentLabel {
    final parent = _byId[_parentId];
    if (parent == null) return 'Top level';
    final path = categoryPathLabel(parent, _byId);
    return parent.isArchived ? '$path (archived)' : path;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typedName = _name.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit category' : 'New category'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  // How the category will look in lists.
                  Container(
                    key: const ValueKey('category-preview'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CategoryAvatar(icon: _icon, color: _color, radius: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typedName.isEmpty ? 'Category name' : typedName,
                                key: const ValueKey('preview-name'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: typedName.isEmpty
                                      ? theme.colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              Text(
                                _parentId == null
                                    ? '${_type == CategoryType.income ? 'Income' : 'Expense'} · top level'
                                    : 'Inside $_parentLabel',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        CategoriesRepository.maxNameLength,
                      ),
                    ],
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 20),
                  SegmentedButton<CategoryType>(
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
                    // The type of an existing category never changes, because
                    // old transactions depend on it.
                    onSelectionChanged: _isEditing
                        ? null
                        : (selection) => setState(() {
                            _type = selection.first;
                            _parentId = null;
                          }),
                  ),
                  if (_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'The type of an existing category cannot be changed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  InkWell(
                    key: const ValueKey('parent-field'),
                    onTap: _chooseParent,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Inside',
                        suffixIcon: Icon(Icons.unfold_more),
                      ),
                      child: Text(
                        _parentLabel,
                        key: const ValueKey('parent-value'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Icon', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final entry in categoryIcons.entries)
                        _PickerCell(
                          key: ValueKey('icon-${entry.key}'),
                          label: entry.key.replaceAll('_', ' '),
                          selected: _icon == entry.key,
                          onTap: () => setState(() => _icon = entry.key),
                          child: Icon(entry.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Color', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final color in categoryColors)
                        _PickerCell(
                          key: ValueKey('color-${color.toRadixString(16)}'),
                          label: 'Color ${color.toRadixString(16)}',
                          selected: _color == color,
                          onTap: () => setState(() => _color = color),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(color),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const ValueKey('form-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? 'Save changes' : 'Add category'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One square in the icon or color picker.
class _PickerCell extends StatelessWidget {
  const _PickerCell({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? scheme.primaryContainer : null,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
