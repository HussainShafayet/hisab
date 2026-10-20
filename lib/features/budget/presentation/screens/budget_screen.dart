import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/month_switcher.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/budget/domain/budget_item.dart';
import 'package:hishab/features/budget/presentation/providers/budget_providers.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_cards.dart';
import 'package:hishab/features/budget/presentation/widgets/budget_limit_dialog.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

class BudgetScreen extends ConsumerStatefulWidget {
  const BudgetScreen({super.key});

  @override
  ConsumerState<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends ConsumerState<BudgetScreen> {
  late DateTime _month = monthStart(ref.read(clockProvider)());

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showMessage(text);
  }

  /// Runs [action] and shows its [ValidationException] message, if any.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (e) {
      if (mounted) _showMessage(describeError(e));
    }
  }

  Future<void> _editOverall(BudgetItem? current) async {
    final result = await showDialog<BudgetDialogResult>(
      context: context,
      builder: (context) => BudgetLimitDialog(
        title: tr('Monthly budget'),
        initialAmount: current?.setAmount,
        canRemove: current != null,
        showNoCarry: ref.read(preferencesProvider).budgetRollover,
        initialNoCarry: current?.noCarry ?? false,
      ),
    );
    if (result == null) return;
    final repository = ref.read(budgetsRepositoryProvider);
    await _run(() async {
      if (result.remove) {
        await repository.removeBudget(current!.id);
      } else {
        await repository.setBudget(
          month: _month,
          amount: result.amount!,
          noCarry: result.noCarry,
        );
      }
    });
  }

  Future<void> _editCategory(BudgetItem item) async {
    final result = await showDialog<BudgetDialogResult>(
      context: context,
      builder: (context) => BudgetLimitDialog(
        title: tr('{name} budget', {'name': item.categoryName}),
        initialAmount: item.setAmount,
        canRemove: true,
        showNoCarry: ref.read(preferencesProvider).budgetRollover,
        initialNoCarry: item.noCarry,
      ),
    );
    if (result == null) return;
    final repository = ref.read(budgetsRepositoryProvider);
    await _run(() async {
      if (result.remove) {
        await repository.removeBudget(item.id);
      } else {
        await repository.setBudget(
          month: _month,
          amount: result.amount!,
          categoryId: item.categoryId,
          noCarry: result.noCarry,
        );
      }
    });
  }

  Future<void> _addCategory(MonthBudget budget) async {
    final categories = await ref
        .read(categoriesRepositoryProvider)
        .getCategories();
    final hasBudget = {for (final item in budget.categories) item.categoryId};
    final byId = {for (final c in categories) c.id: c};
    final choices = [
      for (final category in flattenCategoryTree(
        buildCategoryTree(
          categories.where((c) => c.type == CategoryType.expense),
        ),
      ))
        if (!hasBudget.contains(category.id))
          (id: category.id, label: categoryPathLabel(category, byId)),
    ];
    if (!mounted) return;
    if (choices.isEmpty) {
      _showMessage(tr('Every expense category already has a budget.'));
      return;
    }

    final result = await showDialog<BudgetDialogResult>(
      context: context,
      builder: (context) => BudgetLimitDialog(
        title: tr('Add category budget'),
        categoryChoices: choices,
        showNoCarry: ref.read(preferencesProvider).budgetRollover,
      ),
    );
    if (result == null) return;
    await _run(
      () => ref
          .read(budgetsRepositoryProvider)
          .setBudget(
            month: _month,
            amount: result.amount!,
            categoryId: result.categoryId,
            noCarry: result.noCarry,
          ),
    );
  }

  /// The line under the carry over switch: what it does, or, while it is off,
  /// how much of last month it would have added.
  String _rolloverHint(bool on, int leftoverLastMonth) =>
      !on && leftoverLastMonth > 0
      ? tr('Last month {amount} was left. Switch on to add it to this month.', {
          'amount': formatPoisha(leftoverLastMonth),
        })
      : tr("Money you do not spend is added to next month's budget.");

  Future<void> _copyLastMonth() async {
    final previous = addMonths(_month, -1);
    await _run(() async {
      final copied = await ref
          .read(budgetsRepositoryProvider)
          .copyFromPreviousMonth(_month);
      if (!mounted) return;
      _showMessage(
        copied == 0
            ? tr('Nothing new to copy: this month already has those budgets.')
            : copied == 1
            ? tr('Copied 1 budget from {month}.', {
                'month': monthLabel(previous),
              })
            : tr('Copied {count} budgets from {month}.', {
                'count': copied,
                'month': monthLabel(previous),
              }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final budget = ref.watch(monthBudgetProvider(_month));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Budget')),
        actions: [
          const NotificationBell(),
          const HelpButton('budget'),
          PopupMenuButton<void>(
            itemBuilder: (context) => [
              PopupMenuItem(
                onTap: _copyLastMonth,
                child: Text(tr("Copy last month's budget")),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          MonthSwitcher(
            month: _month,
            // One month ahead, to plan the next month in advance.
            canGoNext: _month.isBefore(addMonths(monthStart(now), 1)),
            onPrevious: () => setState(() => _month = addMonths(_month, -1)),
            onNext: () => setState(() => _month = addMonths(_month, 1)),
          ),
          Expanded(
            child: budget.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(monthBudgetProvider(_month)),
              ),
              data: (data) =>
                  data.isEmpty ? _buildEmpty() : _buildContent(data, now),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyState(
      icon: Icons.account_balance_wallet_outlined,
      title: tr('No budget for {month}', {'month': monthLabel(_month)}),
      message: tr('Set how much you want to spend this month.'),
      action: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FilledButton(
            onPressed: () => _editOverall(null),
            child: Text(tr('Set monthly budget')),
          ),
          TextButton(
            onPressed: _copyLastMonth,
            child: Text(tr("Copy last month's budget")),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(MonthBudget data, DateTime now) {
    final theme = Theme.of(context);
    final overall = data.overall;
    final rollover = ref.watch(
      preferencesProvider.select((p) => p.budgetRollover),
    );
    final leftoverLastMonth =
        ref.watch(lastMonthLeftoverProvider(_month)).value ?? 0;

    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        if (overall != null)
          arriving(
            0,
            OverallBudgetCard(
              item: overall,
              month: _month,
              today: now,
              onTap: () => _editOverall(overall),
            ),
          )
        else
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: ListTile(
              key: const ValueKey('set-overall-budget'),
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(tr('Set a monthly budget')),
              subtitle: Text(tr('One limit for all your spending')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _editOverall(null),
            ),
          ),
        SwitchListTile(
          key: const ValueKey('rollover-switch'),
          secondary: const Icon(Icons.redo),
          title: Text(tr('Carry over what is left')),
          subtitle: Text(_rolloverHint(rollover, leftoverLastMonth)),
          value: rollover,
          onChanged: (value) => _run(
            () => ref
                .read(settingsRepositoryProvider)
                .update((p) => p.copyWith(budgetRollover: value)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(tr('By category'), style: theme.textTheme.titleSmall),
        ),
        if (data.categories.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              tr('No category budgets yet.'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final (index, item) in data.categories.indexed)
          arriving(
            index + 1,
            CategoryBudgetTile(
              key: ValueKey('budget-${item.categoryId}'),
              item: item,
              month: _month,
              today: now,
              onTap: () => _editCategory(item),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _addCategory(data),
              icon: const Icon(Icons.add),
              label: Text(tr('Add category budget')),
            ),
          ),
        ),
      ],
    );
  }
}
