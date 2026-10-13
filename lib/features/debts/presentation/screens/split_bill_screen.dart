import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_avatar.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:hishab/features/debts/domain/split.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';

/// One friend of the split and the controller of their part.
class _Friend {
  _Friend(this.name);

  final String name;
  final share = TextEditingController();

  String get key => name.toLowerCase();
}

/// Splits a bill that you paid for friends. Your part becomes an expense and
/// each friend's part a loan to them, so the account loses the whole bill but
/// only your part counts as spending.
class SplitBillScreen extends ConsumerStatefulWidget {
  const SplitBillScreen({super.key});

  @override
  ConsumerState<SplitBillScreen> createState() => _SplitBillScreenState();
}

class _SplitBillScreenState extends ConsumerState<SplitBillScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _total = TextEditingController();
  final _newFriend = TextEditingController();
  final _friends = <_Friend>[];

  /// Friends taken off the list. Their controllers are disposed with the
  /// screen, since the field is still on screen for the frame they go.
  final _removed = <_Friend>[];
  late DateTime _day = dateOnly(ref.read(clockProvider)());
  int? _accountId;
  int? _categoryId;
  List<Category> _categories = const [];
  List<String> _people = const [];

  /// The parts are the equal ones until someone types in one of them.
  bool _equal = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref
        .read(categoriesRepositoryProvider)
        .getCategories(includeArchived: true)
        .then((all) {
          if (mounted) setState(() => _categories = all);
        });
    ref.read(debtsRepositoryProvider).knownPeople().then((people) {
      if (mounted) setState(() => _people = people);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _total.dispose();
    _newFriend.dispose();
    for (final friend in [..._friends, ..._removed]) {
      friend.share.dispose();
    }
    super.dispose();
  }

  List<Category> get _options => flattenCategoryTree(
    buildCategoryTree([
      for (final c in _categories)
        if (c.type == CategoryType.expense && !c.isArchived) c,
    ]),
  );

  int? get _totalPoisha {
    final value = parseTakaToPoisha(_total.text);
    return value == null || value <= 0 ? null : value;
  }

  /// Fills every part with the equal one, while they are equal.
  void _recalculate() {
    if (!_equal) return;
    final total = _totalPoisha;
    for (final friend in _friends) {
      friend.share.text = total == null || _friends.isEmpty
          ? ''
          : poishaToInput(equalSplit(total, _friends.length).each);
    }
  }

  void _addFriend(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (_friends.any((f) => f.key == clean.toLowerCase())) {
      setState(() => _error = tr('{name} is there twice.', {'name': clean}));
      return;
    }
    if (_friends.length >= maxSplitFriends) {
      setState(
        () => _error = tr('A bill can be split with {max} friends at most.', {
          'max': maxSplitFriends,
        }),
      );
      return;
    }
    setState(() {
      _friends.add(_Friend(clean));
      _newFriend.clear();
      _error = null;
      _recalculate();
    });
  }

  void _removeFriend(_Friend friend) {
    setState(() {
      _friends.remove(friend);
      _removed.add(friend);
      _recalculate();
    });
  }

  Future<void> _chooseCategory() async {
    final pick = await showCategoryPicker(
      context,
      title: tr('Expense category'),
      categories: _options,
      selectedId: _categoryId,
      allowAdd: false,
    );
    if (pick case CategoryPicked(:final id) when mounted) {
      setState(() => _categoryId = id);
    }
  }

  Future<void> _pickDay() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  /// What is left as your part, in poisha; null while the bill is empty.
  int? get _mine {
    final total = _totalPoisha;
    if (total == null) return null;
    var theirs = 0;
    for (final friend in _friends) {
      theirs += parseTakaToPoisha(friend.share.text) ?? 0;
    }
    return total - theirs;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accountId = _accountId;
    final categoryId = _categoryId;
    if (accountId == null) {
      setState(() => _error = tr('Choose an account.'));
      return;
    }
    if (categoryId == null) {
      setState(() => _error = tr('Choose a category.'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(billSplitterProvider)
          .split(
            total: _totalPoisha!,
            accountId: accountId,
            categoryId: categoryId,
            date: _day,
            title: _title.text,
            friends: [
              for (final friend in _friends)
                SplitShare(
                  person: friend.name,
                  amount: parseTakaToPoisha(friend.share.text) ?? 0,
                ),
            ],
          );
      messenger.showMessage(
        tr('Split saved. Your part is {amount}.', {
          'amount': formatPoisha(result.mine),
        }),
      );
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final accounts =
        ref.watch(accountsProvider(false)).value ??
        const <AccountWithBalance>[];
    // The first account is the one to pay from, until another is chosen.
    final accountId =
        _accountId ?? (accounts.isEmpty ? null : accounts.first.account.id);
    if (_accountId == null && accountId != null) _accountId = accountId;
    final byId = {for (final c in _categories) c.id: c};
    final selected = byId[_categoryId];
    final mine = _mine;
    final suggestions = [
      for (final name in _people)
        if (!_friends.any((f) => f.key == name.toLowerCase())) name,
    ].take(6);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Split a bill'))),
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
                  Text(
                    tr(
                      'You paid the bill for everyone. Each friend owes you '
                      'their part, and only your part counts as spending.',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('split-title'),
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    maxLength: 100,
                    decoration: InputDecoration(
                      labelText: tr('What was it for? (optional)'),
                      hintText: tr('Lunch, taxi, tickets...'),
                    ),
                  ),
                  MoneyFormField(
                    key: const ValueKey('split-total'),
                    controller: _total,
                    label: tr('Bill total'),
                    autofocus: true,
                    onChanged: (_) => setState(() {
                      _error = null;
                      _recalculate();
                    }),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    key: ValueKey('split-account-$accountId'),
                    initialValue: accountId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: tr('Paid from')),
                    items: [
                      for (final item in accounts)
                        DropdownMenuItem<int?>(
                          value: item.account.id,
                          child: Text(item.account.name),
                        ),
                    ],
                    onChanged: (value) => setState(() => _accountId = value),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    key: const ValueKey('split-category'),
                    onTap: _chooseCategory,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr('Category of your part'),
                        suffixIcon: const Icon(Icons.unfold_more),
                      ),
                      child: Row(
                        children: [
                          if (selected != null) ...[
                            CategoryAvatar(
                              icon: selected.icon,
                              color: selected.color,
                              radius: 12,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              selected == null
                                  ? tr('Choose a category')
                                  : categoryPathLabel(selected, byId),
                              key: const ValueKey('split-category-value'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DayField(label: tr('Date'), value: _day, onPick: _pickDay),
                  const SizedBox(height: 20),
                  Text(tr('Split with'), style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('split-friend-name'),
                          controller: _newFriend,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            labelText: tr('Add a friend'),
                          ),
                          onSubmitted: _addFriend,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        key: const ValueKey('split-add-friend'),
                        tooltip: tr('Add'),
                        onPressed: () => _addFriend(_newFriend.text),
                        icon: const Icon(Icons.person_add_alt),
                      ),
                    ],
                  ),
                  if (suggestions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final name in suggestions)
                            ActionChip(
                              key: ValueKey(
                                'split-suggest-${name.toLowerCase()}',
                              ),
                              label: Text(name),
                              onPressed: () => _addFriend(name),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  for (final friend in _friends)
                    Padding(
                      key: ValueKey('split-friend-${friend.key}'),
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              friend.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            child: MoneyFormField(
                              key: ValueKey('split-share-${friend.key}'),
                              controller: friend.share,
                              label: tr('Part'),
                              onChanged: (_) => setState(() {
                                _equal = false;
                                _error = null;
                              }),
                            ),
                          ),
                          IconButton(
                            key: ValueKey('split-remove-${friend.key}'),
                            tooltip: tr('Remove'),
                            icon: const Icon(Icons.close),
                            onPressed: () => _removeFriend(friend),
                          ),
                        ],
                      ),
                    ),
                  if (!_equal && _friends.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        key: const ValueKey('split-equal'),
                        onPressed: () => setState(() {
                          _equal = true;
                          _recalculate();
                        }),
                        child: Text(tr('Split equally')),
                      ),
                    ),
                  const SizedBox(height: 12),
                  if (mine != null && _friends.isNotEmpty)
                    Text(
                      mine < 0
                          ? tr('The parts add up to more than the bill.')
                          : tr('Your part: {amount}', {
                              'amount': formatPoisha(mine),
                            }),
                      key: const ValueKey('split-mine'),
                      style: theme.textTheme.titleMedium?.tabular.copyWith(
                        color: mine < 0 ? colors.expense : null,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
                  key: const ValueKey('split-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(tr('Save split')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
