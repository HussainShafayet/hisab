import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/settings/presentation/providers/income_privacy_providers.dart';

/// What stands in place of an income amount while income is hidden: dots, and
/// when [spent] is given, a bar saying how much of the income is spent. The
/// bar is the private part: it means something to the person and nothing to
/// someone looking over their shoulder. Tapping shows the real amount for a
/// few seconds.
class HiddenIncome extends ConsumerWidget {
  const HiddenIncome({this.spent, this.style, super.key});

  /// The share of the income that is spent, 0 to 1 and beyond. Null shows no
  /// bar, for a single entry.
  final double? spent;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final share = spent;
    final barColor = share == null
        ? null
        : share > 1
        ? colors.expense
        : share > 0.8
        ? Colors.orange
        : colors.income;

    return Semantics(
      label: tr('Income is hidden. Tap to show it.'),
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('hidden-income'),
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(incomeRevealProvider.notifier).reveal(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              hiddenAmountText,
              style: style ?? theme.textTheme.titleSmall?.tabular,
            ),
            if (share != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: 56,
                height: 6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    key: const ValueKey('income-spent-bar'),
                    value: share.clamp(0.0, 1.0),
                    color: barColor,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The share of [income] that [expense] is, for the bar of [HiddenIncome].
/// With no income there is nothing to compare with, so no bar (null).
double? spentShare({required int income, required int expense}) =>
    income <= 0 ? null : expense / income;
