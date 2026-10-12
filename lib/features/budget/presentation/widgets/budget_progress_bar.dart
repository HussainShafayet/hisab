import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/features/budget/domain/budget_progress.dart';

/// The color for a budget: the theme color while it is fine, orange from 80%
/// and red once the limit is reached.
Color budgetLevelColor(BuildContext context, BudgetLevel level) {
  final colors = context.financeColors;
  return switch (level) {
    BudgetLevel.ok => Theme.of(context).colorScheme.primary,
    BudgetLevel.warning => colors.warning,
    BudgetLevel.over => colors.expense,
  };
}

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({required this.progress, super.key});

  final BudgetProgress progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tr('{percent}% of the budget used', {'percent': progress.percent}),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.fraction,
          minHeight: 8,
          color: budgetLevelColor(context, progress.level),
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest,
        ),
      ),
    );
  }
}
