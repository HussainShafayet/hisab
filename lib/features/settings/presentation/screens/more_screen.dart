import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/notifications/presentation/widgets/notification_bell.dart';

/// One place in the More list.
class _Entry {
  const _Entry(this.icon, this.title, this.subtitle, this.route);

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
}

/// The "More" tab: entry points to everything that is not a main tab, in
/// groups, each with a line saying what it is for. A search box at the top
/// finds one by what it is called or what it is for.
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// The groups, each with its heading, in the order they are listed.
  List<(String, List<_Entry>)> _groups() => [
    (
      tr('Money'),
      [
        _Entry(
          Icons.account_balance_wallet_outlined,
          tr('Accounts'),
          tr('Cash, bKash, bank and cards'),
          AppRoutes.accounts,
        ),
        _Entry(
          Icons.handshake_outlined,
          tr('Loans'),
          tr('Money you lent or borrowed'),
          AppRoutes.debts,
        ),
        _Entry(
          Icons.storefront_outlined,
          tr('Investments'),
          tr('Money put into a business'),
          AppRoutes.investments,
        ),
        _Entry(
          Icons.diamond_outlined,
          tr('Gold & silver'),
          tr('Your gold and silver, valued today'),
          AppRoutes.metals,
        ),
      ],
    ),
    (
      tr('Plans and shopping'),
      [
        _Entry(
          Icons.flag_outlined,
          tr('Savings goals'),
          tr('Save up for Eid, a laptop or a trip'),
          AppRoutes.goals,
        ),
        _Entry(
          Icons.repeat,
          tr('Recurring'),
          tr('Rent, bills and salary, entered once'),
          AppRoutes.recurring,
        ),
        _Entry(
          Icons.shopping_basket_outlined,
          tr('Bazar list'),
          tr('A shopping list with prices'),
          AppRoutes.bazar,
        ),
      ],
    ),
    (
      tr('Trips and sharing'),
      [
        _Entry(
          Icons.luggage_outlined,
          tr('Trips & events'),
          tr('What a trip or an occasion cost'),
          AppRoutes.tags,
        ),
        _Entry(
          Icons.call_split,
          tr('Split a bill'),
          tr('Share a bill with friends'),
          AppRoutes.splitBill,
        ),
      ],
    ),
    (
      tr('Faith'),
      [
        _Entry(
          Icons.volunteer_activism_outlined,
          tr('Zakat'),
          tr('How much zakat is due'),
          AppRoutes.zakat,
        ),
      ],
    ),
    (
      tr('For fun'),
      [
        _Entry(
          Icons.auto_awesome_outlined,
          tr('Month wrapped'),
          tr('Your month as a short story'),
          AppRoutes.wrapped(),
        ),
        _Entry(
          Icons.timer_outlined,
          tr('Challenges'),
          tr('Dare yourself to spend less'),
          AppRoutes.challenges,
        ),
        _Entry(
          Icons.emoji_events_outlined,
          tr('Badges'),
          tr('Streaks and rewards'),
          AppRoutes.badges,
        ),
      ],
    ),
    (
      tr('Setup'),
      [
        _Entry(
          Icons.category_outlined,
          tr('Categories'),
          tr('Food, transport and the rest'),
          AppRoutes.categories,
        ),
        _Entry(
          Icons.fact_check_outlined,
          tr('Data check'),
          tr('Duplicates, odd dates and amounts'),
          AppRoutes.dataCheck,
        ),
        _Entry(
          Icons.backup_outlined,
          tr('Backup & export'),
          tr('Keep your data safe'),
          AppRoutes.backup,
        ),
        _Entry(
          Icons.settings_outlined,
          tr('Settings'),
          tr('Language, look and alerts'),
          AppRoutes.settings,
        ),
      ],
    ),
  ];

  _Entry get _help => _Entry(
    Icons.help_outline,
    tr('Help & guide'),
    tr('Start here, and a guide for every part'),
    AppRoutes.help,
  );

  bool _matches(_Entry entry, String query) =>
      entry.title.toLowerCase().contains(query) ||
      entry.subtitle.toLowerCase().contains(query);

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('More')),
        actions: const [NotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const ValueKey('more-search'),
              controller: _search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: tr('Search: zakat, loans, backup'),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('more-search-clear'),
                        tooltip: tr('Clear'),
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          if (query.isEmpty) ..._everything() else ..._found(query),
        ],
      ),
    );
  }

  /// The whole list, in groups.
  List<Widget> _everything() {
    final help = _help;
    return [
      _MoreTile(
        key: const ValueKey('more-help'),
        entry: help,
        highlighted: true,
      ),
      for (final (heading, entries) in _groups()) ...[
        _Heading(heading),
        for (final entry in entries) _MoreTile(entry: entry),
      ],
    ];
  }

  /// Only the places that match what was typed.
  List<Widget> _found(String query) {
    final found = [
      if (_matches(_help, query)) _help,
      for (final (_, entries) in _groups())
        for (final entry in entries)
          if (_matches(entry, query)) entry,
    ];
    if (found.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            tr('Nothing matches "{query}".', {'query': _query.trim()}),
            key: const ValueKey('more-search-empty'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 8),
      for (final entry in found) _MoreTile(entry: entry),
    ];
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.entry, this.highlighted = false, super.key});

  final _Entry entry;

  /// The Help tile stands out, so a new person finds it first.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tile = ListTile(
      leading: Icon(entry.icon, color: highlighted ? colors.primary : null),
      title: Text(entry.title),
      subtitle: Text(entry.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(entry.route),
    );
    if (!highlighted) return tile;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: tile,
      ),
    );
  }
}
