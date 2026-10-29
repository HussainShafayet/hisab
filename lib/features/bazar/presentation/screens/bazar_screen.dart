import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';
import 'package:hishab/features/bazar/presentation/providers/bazar_providers.dart';
import 'package:hishab/features/bazar/presentation/widgets/bazar_item_dialog.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

import 'dart:async';

import 'package:intl/intl.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';
import 'package:hishab/features/bazar/data/form_inbox_service.dart';
import 'package:hishab/features/bazar/presentation/form_texts.dart';
import 'package:hishab/features/bazar/presentation/widgets/form_link_dialog.dart';

/// The bazar (shopping) list: add what is needed, tick what is bought, and
/// turn the ticked items into one expense. Prices are remembered, so the next
/// list starts with what things cost last time.
class BazarScreen extends ConsumerStatefulWidget {
  const BazarScreen({super.key});

  @override
  ConsumerState<BazarScreen> createState() => _BazarScreenState();
}

class _BazarScreenState extends ConsumerState<BazarScreen> {
  final _name = TextEditingController();
  String? _error;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    // What other people wrote in the Google Form comes in when the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncWhenLinked());
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _syncWhenLinked() async {
    final status = await ref.read(formInboxStatusProvider.future);
    if (status.linked && mounted) await _syncForm();
  }

  /// Takes the new answers of the Google Form. With [message] the person is
  /// told what came.
  Future<void> _syncForm({bool message = false}) async {
    if (_syncing) return;
    final messenger = ScaffoldMessenger.of(context);
    _syncing = true;
    try {
      final result = await ref
          .read(formInboxServiceProvider)
          .sync(ref.read(clockProvider)());
      if (message && mounted) messenger.showMessage(formResultText(result));
    } finally {
      _syncing = false;
    }
  }

  /// Links a Google Form: asks for the links, reads the sheet to see it works,
  /// asks about the answers that are already there, and takes them.
  Future<void> _setUpForm() async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(formInboxServiceProvider);
    final links = await showFormLinkDialog(context);
    if (links == null || !mounted) return;
    try {
      final count = await service.check(links.sheet);
      var takeExisting = false;
      if (count > 0 && mounted) {
        final choice = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              plural(
                count,
                'The sheet already has 1 answer. Add it to the list?',
                'The sheet already has {n} answers. Add them to the list?',
              ),
            ),
            actions: [
              TextButton(
                key: const ValueKey('form-only-new'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(tr('Only new ones')),
              ),
              FilledButton(
                key: const ValueKey('form-take-all'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(tr('Yes, add them')),
              ),
            ],
          ),
        );
        if (choice == null) return;
        takeExisting = choice;
      }
      final result = await service.link(
        links.sheet,
        formLink: links.form,
        takeExisting: takeExisting,
        now: ref.read(clockProvider)(),
      );
      messenger.showMessage(formResultText(result));
    } on ValidationException catch (error) {
      messenger.showError(error.message);
    } on FormInboxException catch (error) {
      messenger.showError(formProblemText(error.problem, error.detail));
    }
  }

  /// Sends the link of the form to whoever should add to the list.
  Future<void> _shareFormLink(String link) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(fileGatewayProvider).shareText(link);
    } on Object {
      messenger.showError(tr('Could not open the share sheet.'));
    }
  }

  Future<void> _add(String name, {int? price}) async {
    try {
      await ref.read(bazarRepositoryProvider).addItem(name, price: price);
      if (mounted) {
        setState(() {
          _name.clear();
          _error = null;
        });
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  /// Adds an item with how many and the price, from a small form that starts
  /// with what is typed.
  Future<void> _addWithDetails() async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(bazarRepositoryProvider);
    final edit = await showBazarItemDialog(context, name: _name.text.trim());
    if (edit == null || !mounted) return;
    try {
      await repository.addItem(
        edit.name,
        quantity: edit.quantity,
        price: edit.price,
      );
      setState(() {
        _name.clear();
        _error = null;
      });
    } on Object catch (e) {
      messenger.showError(describeError(e));
    }
  }

  /// Takes an item off the list, with a way to get it back.
  Future<void> _remove(ShoppingItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(bazarRepositoryProvider);
    await repository.deleteItem(item.id);
    messenger.showMessage(
      tr('Removed {name}', {'name': item.name}),
      duration: undoDuration,
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.restoreItem(item),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('bazar-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(tr('Remove')),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  Future<void> _removeBought(List<ShoppingItem> list) async {
    final count = list.where((i) => i.isDone).length;
    final yes = await _confirm(
      title: tr('Remove the bought items?'),
      message: plural(
        count,
        'The ticked item leaves the list. No expense is added; use Done '
            'shopping for that.',
        'The {n} ticked items leave the list. No expense is added; use Done '
            'shopping for that.',
      ),
    );
    if (yes) await ref.read(bazarRepositoryProvider).removeBought();
  }

  /// Opens the share sheet with what is still to buy, as a message.
  Future<void> _share(List<ShoppingItem> list) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(fileGatewayProvider)
          .shareText(shoppingListText(list, ref.read(clockProvider)()));
    } on Object {
      messenger.showError(tr('Could not open the share sheet.'));
    }
  }

  Future<void> _clear(List<ShoppingItem> list) async {
    final yes = await _confirm(
      title: tr('Clear the whole list?'),
      message: plural(
        list.length,
        'The item will be removed.',
        'All {n} items will be removed.',
      ),
    );
    if (yes) await ref.read(bazarRepositoryProvider).clearList();
  }

  Future<void> _edit(ShoppingItem item) async {
    final edit = await showBazarItemDialog(context, item: item);
    if (edit == null || !mounted) return;
    try {
      await ref
          .read(bazarRepositoryProvider)
          .updateItem(
            item.id,
            name: edit.name,
            quantity: edit.quantity,
            price: edit.price,
          );
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showError(describeError(e));
      }
    }
  }

  /// Opens the add form with the ticked total; once it is saved the ticked
  /// items leave the list and their prices are remembered.
  Future<void> _finish(List<ShoppingItem> items) async {
    final ticked = [
      for (final item in items)
        if (item.isDone) item,
    ];
    final saved = await context.push<bool>(
      AppRoutes.addWithPrefill(
        amount: totalsOf(items).ticked,
        note: bazarNote(ticked),
      ),
    );
    if (saved == true) {
      await ref.read(bazarRepositoryProvider).finishShopping();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(bazarItemsProvider);
    final formStatus = ref.watch(formInboxStatusProvider).value;
    final theme = Theme.of(context);
    final query = _name.text.trim();
    final suggestions =
        ref.watch(priceSuggestionsProvider(query)).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Bazar list')),
        actions: [
          const HelpButton('bazar'),
          PopupMenuButton<String>(
            key: const ValueKey('bazar-menu'),
            onSelected: (choice) {
              final list = items.value ?? const <ShoppingItem>[];
              switch (choice) {
                case 'share':
                  _share(list);
                case 'prices':
                  context.push(AppRoutes.bazarPrices);
                case 'bought':
                  _removeBought(list);
                case 'clear':
                  _clear(list);
                case 'form-setup':
                  _setUpForm();
                case 'form-sync':
                  _syncForm(message: true);
                case 'form-share':
                  _shareFormLink(formStatus?.formLink ?? '');
                case 'form-off':
                  ref.read(formInboxServiceProvider).unlink();
              }
            },
            itemBuilder: (context) {
              final list = items.value ?? const <ShoppingItem>[];
              return [
                PopupMenuItem(
                  key: const ValueKey('bazar-menu-share'),
                  value: 'share',
                  enabled: list.any((i) => !i.isDone),
                  child: Text(tr('Share the list')),
                ),
                PopupMenuItem(
                  key: const ValueKey('bazar-menu-prices'),
                  value: 'prices',
                  child: Text(tr('Remembered prices')),
                ),
                PopupMenuItem(
                  key: const ValueKey('bazar-menu-bought'),
                  value: 'bought',
                  enabled: list.any((i) => i.isDone),
                  child: Text(tr('Remove bought items')),
                ),
                PopupMenuItem(
                  key: const ValueKey('bazar-menu-clear'),
                  value: 'clear',
                  enabled: list.isNotEmpty,
                  child: Text(tr('Clear the list')),
                ),
                if (formStatus?.linked ?? false) ...[
                  PopupMenuItem(
                    key: const ValueKey('bazar-menu-form-sync'),
                    value: 'form-sync',
                    child: Text(tr('Sync now')),
                  ),
                  if ((formStatus?.formLink ?? '').isNotEmpty)
                    PopupMenuItem(
                      key: const ValueKey('bazar-menu-form-share'),
                      value: 'form-share',
                      child: Text(tr('Send the form link')),
                    ),
                  PopupMenuItem(
                    key: const ValueKey('bazar-menu-form-off'),
                    value: 'form-off',
                    child: Text(tr('Stop adding from the Google Form')),
                  ),
                ] else
                  PopupMenuItem(
                    key: const ValueKey('bazar-menu-form-setup'),
                    value: 'form-setup',
                    child: Text(tr('Add from a Google Form')),
                  ),
              ];
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (formStatus != null && formStatus.linked)
            _FormNote(status: formStatus),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('bazar-name'),
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: tr('Add an item'),
                      hintText: tr('Rice, oil, eggs...'),
                      errorText: _error,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: _add,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  key: const ValueKey('bazar-add-details'),
                  tooltip: tr('Add with how many and the price'),
                  onPressed: _addWithDetails,
                  icon: const Icon(Icons.playlist_add),
                ),
                IconButton.filled(
                  key: const ValueKey('bazar-add'),
                  tooltip: tr('Add'),
                  onPressed: () => _add(_name.text),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          if (suggestions.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final s in suggestions)
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: ActionChip(
                        key: ValueKey('suggest-${priceKey(s.name)}'),
                        label: Text('${s.name} · ${formatPoisha(s.price)}'),
                        onPressed: () => _add(s.name, price: s.price),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(message: describeError(error)),
              data: (list) => list.isEmpty
                  ? EmptyState(
                      icon: Icons.shopping_basket_outlined,
                      title: tr('Your list is empty'),
                      message: tr(
                        'Add what you need to buy. Prices you enter are '
                        'remembered for next time.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 16),
                      children: [
                        for (final (index, item) in list.indexed)
                          arriving(
                            index,
                            _ItemRow(
                              key: ValueKey('item-${item.id}'),
                              item: item,
                              onTick: (done) => ref
                                  .read(bazarRepositoryProvider)
                                  .setDone(item.id, done: done),
                              onEdit: () => _edit(item),
                              onDelete: () => _remove(item),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          if (items.value case final list? when list.isNotEmpty)
            _TotalsBar(
              totals: totalsOf(list),
              onFinish: () => _finish(list),
              theme: theme,
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.onTick,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ShoppingItem item;
  final ValueChanged<bool> onTick;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = item.price;
    final done = item.isDone;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: theme.colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Icon(Icons.delete_outline, color: theme.colorScheme.error),
      ),
      onDismissed: (_) => onDelete(),
      child: ListTile(
        onTap: onEdit,
        leading: Checkbox(
          key: ValueKey('item-check-${item.id}'),
          value: done,
          onChanged: (value) => onTick(value ?? false),
        ),
        title: Text(
          item.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: done
              ? TextStyle(decoration: TextDecoration.lineThrough, color: muted)
              : null,
        ),
        subtitle: Text(
          price == null
              ? tr('No price yet')
              : item.quantity == 1
              ? formatPoisha(price)
              : tr('{count} × {price}', {
                  'count': item.quantity,
                  'price': formatPoisha(price),
                }),
          key: ValueKey('item-sub-${item.id}'),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (price != null)
              Text(
                formatPoisha(item.total),
                key: ValueKey('item-total-${item.id}'),
                style: theme.textTheme.titleSmall?.tabular,
              ),
            PopupMenuButton<String>(
              key: ValueKey('item-menu-${item.id}'),
              onSelected: (choice) => choice == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: ValueKey('item-edit-${item.id}'),
                  value: 'edit',
                  child: Text(tr('Edit')),
                ),
                PopupMenuItem(
                  key: ValueKey('item-delete-${item.id}'),
                  value: 'delete',
                  child: Text(tr('Delete')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalsBar extends StatelessWidget {
  const _TotalsBar({
    required this.totals,
    required this.onFinish,
    required this.theme,
  });

  final ShoppingTotals totals;
  final VoidCallback onFinish;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final colors = context.financeColors;
    return Material(
      elevation: 6,
      color: theme.colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Estimated {amount}', {
                        'amount': formatPoisha(totals.estimated),
                      }),
                      key: const ValueKey('bazar-estimated'),
                      style: theme.textTheme.titleSmall?.tabular,
                    ),
                    Text(
                      totals.tickedCount == 0
                          ? tr('Tick what you bought')
                          : tr('{count} ticked · {amount}', {
                              'count': totals.tickedCount,
                              'amount': formatPoisha(totals.ticked),
                            }),
                      key: const ValueKey('bazar-ticked'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: totals.tickedCount == 0
                            ? theme.colorScheme.onSurfaceVariant
                            : colors.expense,
                      ),
                    ),
                    if (totals.withoutPrice > 0)
                      Text(
                        plural(
                          totals.withoutPrice,
                          '1 item has no price',
                          '{n} items have no price',
                        ),
                        key: const ValueKey('bazar-no-price'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              FilledButton(
                key: const ValueKey('bazar-checkout'),
                onPressed: totals.tickedCount == 0 ? null : onFinish,
                child: Text(tr('Done shopping')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line under the app bar: the list takes what is written in a Google Form,
/// and how the last sync went.
class _FormNote extends StatelessWidget {
  const _FormNote({required this.status});

  final FormInboxStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = status.problem;
    final synced = status.lastSynced;
    final text = problem != null
        ? formProblemText(problem, status.detail)
        : synced != null
        ? tr('Synced {when}.', {
            'when': localizeDigits(DateFormat('d MMM, h:mm a').format(synced)),
          })
        : tr('Not synced yet.');
    final color = problem != null
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Icon(Icons.sync, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${tr('Google Form')} · $text',
              key: const ValueKey('form-status'),
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
