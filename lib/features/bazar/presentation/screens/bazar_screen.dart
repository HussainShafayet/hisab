import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';
import 'package:hishab/features/bazar/presentation/providers/bazar_providers.dart';
import 'package:hishab/features/bazar/presentation/widgets/bazar_item_dialog.dart';

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

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
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

  Future<void> _edit(ShoppingItem item) async {
    final edit = await showBazarItemDialog(context, item);
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
    final theme = Theme.of(context);
    final query = _name.text.trim();
    final suggestions =
        ref.watch(priceSuggestionsProvider(query)).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Bazar list'))),
      body: Column(
        children: [
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
                        for (final item in list)
                          _ItemRow(
                            key: ValueKey('item-${item.id}'),
                            item: item,
                            onTick: (done) => ref
                                .read(bazarRepositoryProvider)
                                .setDone(item.id, done: done),
                            onEdit: () => _edit(item),
                            onDelete: () => ref
                                .read(bazarRepositoryProvider)
                                .deleteItem(item.id),
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
        trailing: price == null
            ? null
            : Text(
                formatPoisha(item.total),
                key: ValueKey('item-total-${item.id}'),
                style: theme.textTheme.titleSmall?.tabular,
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
