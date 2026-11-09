import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';

/// A charge a bank puts on a credit card that the person did not spend. The
/// [title] is also the note of the entry, and [category] the (English) name of
/// the category it is kept in, or null to let the person choose.
enum CardCharge {
  late(Icons.event_busy_outlined, 'Late fee'),
  annual(Icons.autorenew, 'Card annual fee'),
  interest(Icons.percent, 'Card interest'),
  overLimit(Icons.speed, 'Over-limit fee'),
  vat(Icons.receipt_long_outlined, 'Tax'),
  bank(Icons.sms_outlined, 'Bank charge'),
  other(Icons.more_horiz, null);

  const CardCharge(this.icon, this.category);

  final IconData icon;
  final String? category;

  String get title => switch (this) {
    late => tr('Late payment fee'),
    annual => tr('Annual fee'),
    interest => tr('Interest'),
    overLimit => tr('Over-limit fee'),
    vat => tr('VAT or tax on charges'),
    bank => tr('SMS or other bank charge'),
    other => tr('Another charge'),
  };

  String get hint => switch (this) {
    late => tr('The bill was not paid in time'),
    annual => tr('The yearly fee of the card'),
    interest => tr('Charged on what was left unpaid'),
    overLimit => tr('Spending went past the limit'),
    vat => tr('Government tax on the fees above'),
    bank => tr('Small yearly or monthly charges'),
    other => tr('You choose the category'),
  };
}

/// Asks which charge it was, then opens the add form as an expense on the card
/// with the category and the note filled in. The amount is typed there: it
/// adds to what is owed on the card, and counts as an expense.
Future<void> addCardCharge(
  BuildContext context,
  WidgetRef ref, {
  required int cardId,
}) async {
  final charge = await showModalBottomSheet<CardCharge>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _ChargeSheet(),
  );
  if (charge == null || !context.mounted) return;
  final category = charge.category;
  final categoryId = category == null
      ? null
      : await ref.read(categoriesRepositoryProvider).feeCategoryId(category);
  if (!context.mounted) return;
  await context.push(
    AppRoutes.cardCharge(cardId, categoryId: categoryId, note: charge.title),
  );
}

class _ChargeSheet extends StatelessWidget {
  const _ChargeSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text(
                tr('What did the bank charge?'),
                style: theme.textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                tr(
                  'It is added to what you owe on the card, and counts as an '
                  'expense.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final charge in CardCharge.values)
              ListTile(
                key: ValueKey('card-charge-${charge.name}'),
                leading: Icon(charge.icon),
                title: Text(charge.title),
                subtitle: Text(charge.hint),
                onTap: () => Navigator.of(context).pop(charge),
              ),
          ],
        ),
      ),
    );
  }
}
