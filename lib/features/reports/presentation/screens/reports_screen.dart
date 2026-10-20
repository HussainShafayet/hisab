import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/date_range_picker.dart';
import 'package:hishab/core/widgets/month_switcher.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/range_banner.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:hishab/features/reports/domain/report_data.dart';
import 'package:hishab/features/reports/presentation/providers/reports_providers.dart';
import 'package:hishab/features/reports/presentation/widgets/category_tree_card.dart';
import 'package:hishab/features/reports/presentation/widgets/report_cards.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// Where the money went: totals, spending by category, income against expense
/// over the last months, and the biggest expenses. For a month, or any range
/// of days.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTime _month = monthStart(ref.read(clockProvider)());

  /// A custom range, which replaces the month while it is set.
  DateRange? _custom;

  Future<void> _pickRange() async {
    final picked = await pickDateRange(
      context,
      today: dateOnly(ref.read(clockProvider)()),
      initial: _custom,
    );
    if (picked != null && mounted) setState(() => _custom = picked);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final range = _custom ?? monthRange(_month);
    final report = ref.watch(reportProvider(range));

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Reports')),
        actions: [
          const NotificationBell(),
          const HelpButton('reports'),
          IconButton(
            tooltip: tr('Custom date range'),
            icon: const Icon(Icons.date_range),
            onPressed: _pickRange,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_custom case final custom?)
            RangeBanner(
              range: custom,
              onClear: () => setState(() => _custom = null),
            )
          else
            MonthSwitcher(
              month: _month,
              canGoNext: _month.isBefore(monthStart(now)),
              onPrevious: () => setState(() => _month = addMonths(_month, -1)),
              onNext: () => setState(() => _month = addMonths(_month, 1)),
            ),
          Expanded(
            child: report.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(reportProvider(range)),
              ),
              data: (data) =>
                  _ReportContent(data: data, isCustom: _custom != null),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({required this.data, required this.isCustom});

  final ReportData data;
  final bool isCustom;

  @override
  Widget build(BuildContext context) {
    return ListView(
      // Room below the last row so the add button never covers it.
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        for (final (index, card) in [
          ReportSummaryCard(
            totals: data.totals,
            previousTotals: data.previousTotals,
            previousLabel: isCustom
                ? rangeLabel(data.previousRange)
                : monthLabel(data.previousRange.start),
            days: daysBetween(data.range.start, data.range.end),
          ),
          CategoryPieCard(
            categories: data.categories,
            incomeCategories: data.incomeCategories,
          ),
          CategoryTreeCard(
            expense: data.expenseBranches,
            income: data.incomeBranches,
          ),
          AccountBreakdownCard(accounts: data.accounts),
          IncomeExpenseBarCard(months: data.months),
          TopExpensesCard(items: data.topExpenses),
        ].indexed)
          arriving(index, card),
      ],
    );
  }
}
