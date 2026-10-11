import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/transactions/domain/day_groups.dart';
import 'package:hishab/features/transactions/domain/transaction_filter.dart';
import 'package:hishab/features/transactions/domain/transaction_item.dart';
import 'package:hishab/features/transactions/presentation/providers/transactions_providers.dart';
import 'package:hishab/features/transactions/presentation/widgets/month_switcher.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_filter_sheet.dart';
import 'package:hishab/features/transactions/presentation/widgets/transaction_tile.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late DateTime _month = monthStart(ref.read(clockProvider)());
  TransactionFilter _filter = const TransactionFilter();
  bool _searching = false;
  final _search = TextEditingController();

  /// Deleted rows stay hidden here until the database stream catches up. A
  /// swiped `Dismissible` must leave the tree in the same frame.
  final _hiddenIds = <int>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      if (_searching) {
        _search.clear();
        _filter = _filter.withQuery('');
      }
      _searching = !_searching;
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TransactionFilterSheet(initial: _filter),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  void _clearFilters() {
    _search.clear();
    setState(() => _filter = const TransactionFilter());
  }

  Future<void> _edit(TransactionItem item) =>
      context.push(AppRoutes.editTransaction(item.id));

  Future<void> _delete(TransactionItem item) async {
    final repository = ref.read(transactionsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiddenIds.add(item.id));

    final TransactionItem? deleted;
    try {
      deleted = await repository.deleteTransaction(item.id);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _hiddenIds.remove(item.id));
      messenger.showSnackBar(SnackBar(content: Text(describeError(error))));
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Transaction deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            await repository.restoreTransaction(deleted ?? item);
            if (mounted) setState(() => _hiddenIds.remove(item.id));
          },
        ),
      ),
    );
  }

  Future<void> _showActions(TransactionItem item) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _edit(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Duplicate'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.duplicateTransaction(item.id));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _delete(item);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final range = _filter.range ?? monthRange(_month);
    final transactions = ref.watch(transactionsInRangeProvider(range));
    final optionCount = _filter.sheetOptionCount;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search note, category or amount',
                  border: InputBorder.none,
                ),
                onChanged: (text) =>
                    setState(() => _filter = _filter.withQuery(text)),
              )
            : const Text('Transactions'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          IconButton(
            tooltip: 'Filter',
            icon: Badge(
              isLabelVisible: optionCount > 0,
              label: Text('$optionCount'),
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_filter.range case final customRange?)
            _RangeBanner(
              range: customRange,
              onClear: () => setState(() => _filter = _filter.withoutRange()),
            )
          else
            MonthSwitcher(
              month: _month,
              canGoNext: _month.isBefore(monthStart(now)),
              onPrevious: () => setState(() => _month = addMonths(_month, -1)),
              onNext: () => setState(() => _month = addMonths(_month, 1)),
            ),
          Expanded(
            child: transactions.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: describeError(error),
                onRetry: () =>
                    ref.invalidate(transactionsInRangeProvider(range)),
              ),
              data: (all) => _buildList(context, all, now),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<TransactionItem> all,
    DateTime now,
  ) {
    final present = all.where((item) => !_hiddenIds.contains(item.id)).toList();
    final shown = applyTransactionFilter(present, _filter);

    if (shown.isEmpty) {
      if (_filter.isActive) {
        return EmptyState(
          icon: Icons.search_off,
          title: 'Nothing matches',
          message: 'No transaction fits your search and filters.',
          action: FilledButton(
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
        );
      }
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No transactions in ${monthLabel(_month)}',
        message: 'Tap + to add your first one.',
        action: FilledButton(
          onPressed: () => context.push(AppRoutes.addTransaction),
          child: const Text('Add transaction'),
        ),
      );
    }

    final totals = totalsOf(shown);
    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        TransactionSummary(income: totals.income, expense: totals.expense),
        for (final group in groupByDay(shown)) ...[
          DayHeader(group: group, label: dayLabel(group.day, now)),
          for (final item in group.items) _buildRow(context, item),
        ],
      ],
    );
  }

  Widget _buildRow(BuildContext context, TransactionItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('transaction-${item.id}'),
      background: _SwipeBackground(
        color: scheme.primaryContainer,
        iconColor: scheme.onPrimaryContainer,
        icon: Icons.edit_outlined,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: scheme.errorContainer,
        iconColor: scheme.onErrorContainer,
        icon: Icons.delete_outline,
        alignment: Alignment.centerRight,
      ),
      // Swiping right opens the editor and snaps back; swiping left deletes.
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _edit(item);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _delete(item),
      child: TransactionTile(
        item: item,
        onTap: () => _edit(item),
        onLongPress: () => _showActions(item),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.iconColor,
    required this.icon,
    required this.alignment,
  });

  final Color color;
  final Color iconColor;
  final IconData icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(icon, color: iconColor),
    );
  }
}

class _RangeBanner extends StatelessWidget {
  const _RangeBanner({required this.range, required this.onClear});

  final DateRange range;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Row(
        children: [
          const Icon(Icons.date_range, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rangeLabel(range),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Clear date range',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
