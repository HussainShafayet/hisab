import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';
import 'package:hishab/features/bazar/presentation/providers/bazar_providers.dart';
import 'package:hishab/features/bazar/presentation/widgets/bazar_price_dialog.dart';
import 'package:intl/intl.dart';

/// The prices the bazar list remembers: see them, add one, change one, and
/// remove the ones that are out of date.
class BazarPricesScreen extends ConsumerWidget {
  const BazarPricesScreen({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    RememberedPrice? price,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final edit = await showBazarPriceDialog(context, price: price);
    if (edit == null) return;
    try {
      await ref
          .read(bazarRepositoryProvider)
          .savePrice(
            name: edit.name,
            price: edit.price,
            replacing: price?.name,
          );
    } on Object catch (e) {
      messenger.showError(describeError(e));
    }
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    RememberedPrice price,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(bazarRepositoryProvider);
    await repository.deletePrice(price.name);
    messenger.showMessage(
      tr('Removed the price of {name}', {'name': price.name}),
      action: SnackBarAction(
        label: tr('Undo'),
        onPressed: () => repository.restorePrice(price),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prices = ref.watch(rememberedPricesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Remembered prices'))),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('price-add'),
        tooltip: tr('Add a price'),
        onPressed: () => _save(context, ref),
        child: const Icon(Icons.add),
      ),
      body: prices.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.sell_outlined,
                title: tr('No remembered prices yet'),
                message: tr(
                  'Prices you enter on the list, and after shopping, are '
                  'kept here for next time.',
                ),
              )
            : ListView(
                padding: const EdgeInsets.only(bottom: 96),
                children: [
                  for (final price in list)
                    _PriceRow(
                      key: ValueKey('price-${price.key}'),
                      price: price,
                      onEdit: () => _save(context, ref, price: price),
                      onDelete: () => _remove(context, ref, price),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.price,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final RememberedPrice price;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey('price-dismiss-${price.key}'),
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
        title: Text(price.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          tr('Updated {date}', {
            'date': DateFormat('d MMM yyyy').format(price.updatedAt),
          }),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatPoisha(price.price),
              style: theme.textTheme.titleSmall?.tabular,
            ),
            PopupMenuButton<String>(
              key: ValueKey('price-menu-${price.key}'),
              onSelected: (choice) => choice == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => [
                PopupMenuItem(
                  key: ValueKey('price-edit-${price.key}'),
                  value: 'edit',
                  child: Text(tr('Edit')),
                ),
                PopupMenuItem(
                  key: ValueKey('price-delete-${price.key}'),
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
