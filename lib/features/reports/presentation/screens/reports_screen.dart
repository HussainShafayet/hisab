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
import 'package:hishab/core/widgets/year_switcher.dart';
import 'package:hishab/features/reports/domain/period_totals.dart';
import 'package:hishab/features/reports/presentation/widgets/year_cards.dart';
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

  /// The year view: a whole calendar year instead of a month.
  bool _yearMode = false;
  late int _year = ref.read(clockProvider)().year;

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
    final range =
        _custom ?? (_yearMode ? yearRange(_year) : monthRange(_month));
    final report = ref.watch(reportProvider(range));
    final yearMonths = _yearMode && _custom == null
        ? ref.watch(yearMonthsProvider(_year)).value
        : null;

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
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SegmentedButton<bool>(
                key: const ValueKey('report-mode'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: false, label: Text(tr('Month'))),
                  ButtonSegment(value: true, label: Text(tr('Year'))),
                ],
                selected: {_yearMode},
                onSelectionChanged: (chosen) =>
                    setState(() => _yearMode = chosen.first),
              ),
            ),
            if (_yearMode)
              YearSwitcher(
                year: _year,
                canGoNext: _year < now.year,
                onPrevious: () => setState(() => _year--),
                onNext: () => setState(() => _year++),
              )
            else
              MonthSwitcher(
                month: _month,
                canGoNext: _month.isBefore(monthStart(now)),
                onPrevious: () =>
                    setState(() => _month = addMonths(_month, -1)),
                onNext: () => setState(() => _month = addMonths(_month, 1)),
              ),
          ],
          Expanded(
            child: report.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorView(
                message: describeError(error),
                onRetry: () => ref.invalidate(reportProvider(range)),
              ),
              data: (data) => _ReportContent(
                data: data,
                isCustom: _custom != null,
                now: now,
                yearMonths: yearMonths,
                onOpenMonth: (month) => setState(() {
                  _yearMode = false;
                  _month = monthStart(month);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportContent extends StatelessWidget {
  const _ReportContent({
    required this.data,
    required this.isCustom,
    required this.now,
    this.yearMonths,
    this.onOpenMonth,
  });

  final ReportData data;
  final bool isCustom;
  final DateTime now;

  /// The twelve months of the year when the report is for a year, else null.
  final List<MonthTotals>? yearMonths;

  /// Opens a month of the year view.
  final ValueChanged<DateTime>? onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final months = yearMonths;
    final isYear = months != null;
    // This year is only as long as it has been.
    final tomorrow = dateOnly(now).add(const Duration(days: 1));
    final end = data.range.end.isAfter(tomorrow) ? tomorrow : data.range.end;
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
                : isYear
                ? localizeDigits('${data.previousRange.start.year}')
                : monthLabel(data.previousRange.start),
            days: daysBetween(data.range.start, end),
          ),
          if (months != null) ...[
            IncomeExpenseBarCard(months: months),
            MonthByMonthCard(
              months: months,
              now: now,
              onOpen: (month) => onOpenMonth?.call(month),
            ),
          ],
          CategoryPieCard(
            categories: data.categories,
            incomeCategories: data.incomeCategories,
          ),
          CategoryTreeCard(
            expense: data.expenseBranches,
            income: data.incomeBranches,
          ),
          AccountBreakdownCard(accounts: data.accounts),
          if (!isYear) IncomeExpenseBarCard(months: data.months),
          TopExpensesCard(items: data.topExpenses),
        ].indexed)
          arriving(index, card),
      ],
    );
  }
}
