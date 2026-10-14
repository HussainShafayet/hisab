import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';
import 'package:hishab/features/fun/domain/wrapped.dart';
import 'package:hishab/features/fun/presentation/providers/wrapped_providers.dart';
import 'package:hishab/features/fun/presentation/widgets/takka.dart';
import 'package:hishab/features/transactions/domain/feeling_summary.dart';
import 'package:intl/intl.dart';

/// One card of the wrapped: a picture (an icon or Takka), a line above, the
/// big thing, and a line below.
class WrapPage {
  const WrapPage({
    required this.title,
    required this.big,
    this.caption,
    this.icon,
    this.mood,
    this.last = false,
  });

  final String title;
  final String big;
  final String? caption;
  final IconData? icon;

  /// Takka's face, when Takka is the picture.
  final TakkaMood? mood;

  /// The card with the Done button.
  final bool last;
}

List<WrapPage> wrappedPages(MonthWrapped w) {
  final label = monthLabel(w.month);
  if (w.isEmpty) {
    return [
      WrapPage(
        title: tr('Your {month} in Hishab', {'month': label}),
        big: tr('Nothing written yet'),
        caption: tr('Write a few entries and come back.'),
        mood: TakkaMood.sleepy,
        last: true,
      ),
    ];
  }
  final top = w.topCategory;
  final biggest = w.biggest;
  return [
    WrapPage(
      title: tr('Your {month} in Hishab', {'month': label}),
      big: wrappedPersona(top),
      caption: tr('This is how you went about money this month.'),
      mood: TakkaMood.party,
    ),
    WrapPage(
      title: tr('Money in, money out'),
      big: formatPoisha(w.expense),
      caption:
          '${tr('You earned {income} and spent {expense}.', {'income': formatPoisha(w.income), 'expense': formatPoisha(w.expense)})}\n'
          '${w.saved >= 0 ? tr('You kept {amount}. Shabash!', {'amount': formatPoisha(w.saved)}) : tr('You spent {amount} more than you earned.', {'amount': formatPoisha(-w.saved)})}',
      icon: Icons.account_balance_wallet_outlined,
    ),
    if (top != null)
      WrapPage(
        title: tr('Most of your money went to'),
        big: tr(top),
        caption: tr('{amount}, {percent}% of your spending.', {
          'amount': formatPoisha(w.topCategoryAmount),
          'percent': (w.topShare * 100).round(),
        }),
        icon: Icons.pie_chart_outline,
      ),
    if (biggest != null)
      WrapPage(
        title: tr('Your biggest single spend'),
        big: formatPoisha(biggest.amount),
        caption: [
          if (biggest.categoryName != null) tr(biggest.categoryName!),
          DateFormat('d MMM').format(biggest.date),
          if (biggest.note.isNotEmpty) biggest.note,
        ].join(' · '),
        icon: Icons.trending_up,
      ),
    WrapPage(
      title: tr('Days you showed up'),
      big: plural(w.entries, '1 entry', '{n} entries'),
      caption: w.spendFreeDays > 0
          ? plural(
              w.spendFreeDays,
              'And 1 day with no spending.',
              'And {n} days with no spending.',
            )
          : tr('Try a day with no spending next month!'),
      icon: Icons.edit_calendar_outlined,
    ),
    if (!w.feelings.isEmpty)
      WrapPage(
        title: tr('How it felt'),
        big: w.feelings.regret == 0
            ? tr('No regrets!')
            : formatPoisha(w.feelings.regret),
        caption:
            '${tr('Needed {need} · Wanted {want} · Regret {regret}', {'need': formatPoisha(w.feelings.need), 'want': formatPoisha(w.feelings.want), 'regret': formatPoisha(w.feelings.regret)})}\n'
            '${regretLine(w.feelings, formatPoisha(w.feelings.regret))}',
        icon: Icons.sentiment_satisfied_alt_outlined,
      ),
    WrapPage(
      title: tr('That was your month'),
      big: tr('See you next month!'),
      mood: TakkaMood.happy,
      last: true,
    ),
  ];
}

/// The month in swipeable cards: who you were with money, what you earned and
/// spent, where it went, the biggest spend, the days you wrote, and how it
/// felt.
class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({this.month, super.key});

  /// Any day in the month; this month, or the one just over, when null.
  final DateTime? month;

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  final _controller = PageController();
  var _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final month = monthStart(
      widget.month ?? wrappedMonthFor(now) ?? monthStart(now),
    );
    final data = ref.watch(wrappedProvider(month));
    final title = Text(tr('Month wrapped'));

    return Scaffold(
      appBar: AppBar(title: title),
      body: data.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (wrapped) {
          final pages = wrappedPages(wrapped);
          return Column(
            children: [
              Expanded(
                child: PageView(
                  key: const ValueKey('wrapped-pages'),
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    for (final (i, page) in pages.indexed)
                      _Card(page: page, index: i),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < pages.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.page, required this.index});

  final WrapPage page;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    // Each card has its own tint, so swiping feels like a change.
    final tints = [
      colors.primaryContainer,
      colors.tertiaryContainer,
      colors.secondaryContainer,
    ];
    final tint = tints[index % tints.length];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: DecoratedBox(
        key: ValueKey('wrapped-card-$index'),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tint, colors.surface],
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (page.mood != null)
                Takka(mood: page.mood!, size: 96)
              else
                Icon(page.icon, size: 64, color: colors.primary),
              const SizedBox(height: 24),
              Text(
                page.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  page.big,
                  key: ValueKey('wrapped-big-$index'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.tabular.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (page.caption != null) ...[
                const SizedBox(height: 12),
                Text(
                  page.caption!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              if (page.last) ...[
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('wrapped-done'),
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(tr('Done')),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
