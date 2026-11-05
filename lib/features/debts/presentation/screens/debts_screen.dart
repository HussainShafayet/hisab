import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/credit_card_tile.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/domain/loan_insights.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/loan_list_item.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';

/// Money lent and borrowed, and credit card bills: what I will get and what I
/// will give, in three tabs (money coming in, money going out, and people).
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  bool _showSettled = false;
  bool _searching = false;
  String _query = '';
  LoanSort _sort = LoanSort.due;

  /// Opens a new loan that starts the way of the tab that is open: "I'll give"
  /// is a loan taken (borrowed), the others are a loan given. [context] must be
  /// below the tab controller.
  void _addLoan(BuildContext context) {
    final tab = DefaultTabController.maybeOf(context)?.index ?? 0;
    context.push(
      tab == 1
          ? AppRoutes.newDebtGoing(DebtDirection.borrowed.name)
          : AppRoutes.newDebt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final cards = ref.watch(creditCardsProvider);
    final today = ref.read(clockProvider)();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  key: const ValueKey('loan-search'),
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: tr('Search a name or note'),
                    border: InputBorder.none,
                  ),
                  onChanged: (text) => setState(() => _query = text),
                )
              : Text(tr('Loans')),
          actions: [
            const HelpButton('loans'),
            IconButton(
              key: const ValueKey('loan-search-toggle'),
              tooltip: _searching ? tr('Close search') : tr('Search'),
              icon: Icon(_searching ? Icons.close : Icons.search),
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              }),
            ),
            PopupMenuButton<LoanSort>(
              key: const ValueKey('loan-sort'),
              tooltip: tr('Sort'),
              icon: const Icon(Icons.sort),
              initialValue: _sort,
              onSelected: (sort) => setState(() => _sort = sort),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: LoanSort.due,
                  child: Text(tr('Late and due first')),
                ),
                PopupMenuItem(
                  value: LoanSort.biggest,
                  child: Text(tr('Biggest left first')),
                ),
                PopupMenuItem(
                  value: LoanSort.newest,
                  child: Text(tr('Newest first')),
                ),
              ],
            ),
            IconButton(
              key: const ValueKey('split-bill'),
              tooltip: tr('Split a bill'),
              icon: const Icon(Icons.call_split),
              onPressed: () => context.push(AppRoutes.splitBill),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(key: const ValueKey('tab-get'), text: tr("I'll get")),
              Tab(key: const ValueKey('tab-give'), text: tr("I'll give")),
              Tab(key: const ValueKey('tab-people'), text: tr('People')),
            ],
          ),
        ),
        // Below the tab controller, so it can tell which tab is open.
        floatingActionButton: Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: () => _addLoan(context),
            icon: const Icon(Icons.add),
            label: Text(tr('Add loan')),
          ),
        ),
        body: debts.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(debtsProvider),
          ),
          data: (items) {
            if (items.isEmpty && cards.isEmpty) {
              return EmptyState(
                icon: Icons.handshake_outlined,
                title: tr('No loans yet'),
                message: tr(
                  'Note down money you gave or took, and tick it off when it '
                  'comes back. Credit card bills show up here too.',
                ),
                action: Builder(
                  builder: (context) => FilledButton(
                    onPressed: () => _addLoan(context),
                    child: Text(tr('Add loan')),
                  ),
                ),
              );
            }
            final totals = debtTotals(items, today);
            return Column(
              children: [
                _Summary(
                  totals: totals,
                  cardsOwed: totalOwed(cards),
                  net: netPosition(totals, cardsOwed: totalOwed(cards)),
                ),
                _UpcomingCard(dues: upcomingDues(items, today)),
                Expanded(
                  child: TabBarView(
                    children: [
                      _LoanList(
                        items: items,
                        direction: DebtDirection.lent,
                        cards: const [],
                        today: today,
                        showSettled: _showSettled,
                        onShowSettled: (v) => setState(() => _showSettled = v),
                        query: _query,
                        sort: _sort,
                      ),
                      _LoanList(
                        items: items,
                        direction: DebtDirection.borrowed,
                        cards: cards,
                        today: today,
                        showSettled: _showSettled,
                        onShowSettled: (v) => setState(() => _showSettled = v),
                        query: _query,
                        sort: _sort,
                      ),
                      _PeopleList(
                        items: searchAndSort(
                          items,
                          query: _query,
                          sort: LoanSort.due,
                          today: today,
                        ),
                        today: today,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The loans that go one way, with the credit cards on the "give" side.
class _LoanList extends ConsumerWidget {
  const _LoanList({
    required this.items,
    required this.direction,
    required this.cards,
    required this.today,
    required this.showSettled,
    required this.onShowSettled,
    this.query = '',
    this.sort = LoanSort.due,
  });

  final String query;
  final LoanSort sort;

  final List<DebtItem> items;
  final DebtDirection direction;
  final List<CreditCardStatus> cards;
  final DateTime today;
  final bool showSettled;
  final ValueChanged<bool> onShowSettled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mine = searchAndSort(
      debtsGoing(items, direction, today),
      query: query,
      sort: sort,
      today: today,
    );
    final shown = mine.where((i) => showSettled || !i.isSettled).toList();
    final hasSettled = mine.any((i) => i.isSettled);
    final lent = direction == DebtDirection.lent;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      children: [
        if (cards.isNotEmpty) ...[
          heading(tr('Credit cards')),
          for (final (index, card) in cards.indexed)
            arriving(
              index,
              CreditCardTile(
                key: ValueKey('card-${card.account.id}'),
                card: card,
                today: today,
                onTap: () =>
                    context.push(AppRoutes.editAccount(card.account.id)),
                onPay: () => context.push(
                  AppRoutes.payCardBill(
                    card.account.id,
                    card.owed,
                    usd: card.dollars.due,
                  ),
                ),
              ),
            ),
          if (shown.isNotEmpty || hasSettled) heading(tr('People')),
        ],
        if (hasSettled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                key: const ValueKey('show-settled'),
                avatar: const Icon(Icons.done_all, size: 18),
                label: Text(tr('Show paid ones')),
                selected: showSettled,
                onSelected: onShowSettled,
              ),
            ),
          ),
        if (shown.isEmpty && cards.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                mine.isEmpty
                    ? (lent
                          ? tr('Nobody owes you anything.')
                          : tr('You do not owe anyone anything.'))
                    : tr('Everything is paid.'),
                key: const ValueKey('list-empty'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        for (final (index, item) in shown.indexed)
          arriving(
            cards.length + index,
            LoanListItem(item: item, today: today),
          ),
      ],
    );
  }
}

/// Everyone I have a loan with, and what is left between us.
class _PeopleList extends StatelessWidget {
  const _PeopleList({required this.items, required this.today});

  final List<DebtItem> items;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final people = groupByPerson(items, today);
    if (people.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            tr('People you lend to or borrow from show up here.'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 96),
      children: [
        for (final (index, person) in people.indexed)
          arriving(index, _PersonTile(person: person, today: today)),
      ],
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({required this.person, required this.today});

  final PersonDebts person;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final net = person.net;
    final late = person.overdueCount(today) > 0;
    final color = person.isSettled
        ? theme.colorScheme.onSurfaceVariant
        : (net > 0
              ? colors.income
              : (net < 0 ? colors.expense : theme.colorScheme.onSurface));
    final openCount = person.items.where((i) => !i.isSettled).length;

    final String status;
    if (person.isSettled) {
      status = tr('All paid');
    } else if (net > 0) {
      status = tr('Owes you');
    } else if (net < 0) {
      status = tr('You owe');
    } else {
      status = tr('Even');
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('person-tile-${personKey(person.name)}'),
        onTap: () => context.push(AppRoutes.debtPerson(person.name)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                foregroundColor: color,
                child: Text(person.name.characters.first.toUpperCase()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      [
                        status,
                        if (openCount > 0)
                          openCount == 1
                              ? tr('1 loan')
                              : tr('{count} loans', {'count': openCount}),
                        if (late) tr('Late'),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: late
                            ? colors.expense
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    person.isSettled ? '' : formatPoisha(net.abs()),
                    key: ValueKey('person-net-${personKey(person.name)}'),
                    style: theme.textTheme.titleLarge?.tabular.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.totals,
    required this.cardsOwed,
    required this.net,
  });

  final DebtTotals totals;
  final int cardsOwed;

  /// What I will get less what I will give, in poisha.
  final int net;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;

    Widget side(String key, String label, int amount, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatPoisha(amount),
              key: ValueKey(key),
              style: theme.textTheme.headlineSmall?.tabular.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                side(
                  'to-get-back',
                  tr("I'll get"),
                  totals.toReceive,
                  colors.income,
                ),
                const SizedBox(width: 16),
                side(
                  'to-pay-back',
                  tr("I'll give"),
                  totals.toPay + cardsOwed,
                  colors.expense,
                ),
              ],
            ),
            if (net != 0 || totals.toReceive > 0 || totals.toPay > 0) ...[
              const SizedBox(height: 8),
              Text(
                net == 0
                    ? tr('You are even.')
                    : net > 0
                    ? tr('You will get {amount} more than you give.', {
                        'amount': formatPoisha(net),
                      })
                    : tr('You will give {amount} more than you get.', {
                        'amount': formatPoisha(-net),
                      }),
                key: const ValueKey('loan-net'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (cardsOwed > 0 && totals.toPay > 0) ...[
              const SizedBox(height: 8),
              Text(
                tr('{loans} to people and {cards} on credit cards', {
                  'loans': formatPoisha(totals.toPay),
                  'cards': formatPoisha(cardsOwed),
                }),
                key: const ValueKey('give-split'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (totals.overdueCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: colors.expense),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      totals.overdueCount == 1
                          ? tr('1 loan is late')
                          : tr('{count} loans are late', {
                              'count': totals.overdueCount,
                            }),
                      key: const ValueKey('overdue-count'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.expense,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The next loans to fall due, soonest first, a tap away.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.dues});

  final List<UpcomingDue> dues;

  @override
  Widget build(BuildContext context) {
    if (dues.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colors = context.financeColors;
    return Card(
      key: const ValueKey('loan-upcoming'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Coming up'), style: theme.textTheme.labelLarge),
            for (final due in dues)
              InkWell(
                key: ValueKey('upcoming-${due.item.debt.id}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => context.push(AppRoutes.debt(due.item.debt.id)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Icon(
                        due.item.debt.direction == DebtDirection.lent
                            ? Icons.south_west
                            : Icons.north_east,
                        size: 18,
                        color: due.item.debt.direction == DebtDirection.lent
                            ? colors.income
                            : colors.expense,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${due.item.debt.person} · '
                          '${formatPoisha(due.item.remaining)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        due.daysLeft == 0
                            ? tr('Today')
                            : due.daysLeft == 1
                            ? tr('Tomorrow')
                            : tr('in {n} days', {'n': due.daysLeft}),
                        style: theme.textTheme.bodySmall,
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
