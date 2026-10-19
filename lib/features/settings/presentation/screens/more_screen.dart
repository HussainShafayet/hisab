import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The "More" tab: entry points to everything that is not a main tab, in
/// groups, each with a line saying what it is for.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('More'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _MoreTile(
            key: const ValueKey('more-help'),
            icon: Icons.help_outline,
            title: tr('Help & guide'),
            subtitle: tr('Start here, and a guide for every part'),
            route: AppRoutes.help,
            highlighted: true,
          ),
          _Heading(tr('Money')),
          _MoreTile(
            icon: Icons.account_balance_wallet_outlined,
            title: tr('Accounts'),
            subtitle: tr('Cash, bKash, bank and cards'),
            route: AppRoutes.accounts,
          ),
          _MoreTile(
            icon: Icons.handshake_outlined,
            title: tr('Loans'),
            subtitle: tr('Money you lent or borrowed'),
            route: AppRoutes.debts,
          ),
          _MoreTile(
            icon: Icons.storefront_outlined,
            title: tr('Investments'),
            subtitle: tr('Money put into a business'),
            route: AppRoutes.investments,
          ),
          _MoreTile(
            icon: Icons.diamond_outlined,
            title: tr('Gold & silver'),
            subtitle: tr('Your gold and silver, valued today'),
            route: AppRoutes.metals,
          ),
          _Heading(tr('Plans and shopping')),
          _MoreTile(
            icon: Icons.flag_outlined,
            title: tr('Savings goals'),
            subtitle: tr('Save up for Eid, a laptop or a trip'),
            route: AppRoutes.goals,
          ),
          _MoreTile(
            icon: Icons.repeat,
            title: tr('Recurring'),
            subtitle: tr('Rent, bills and salary, entered once'),
            route: AppRoutes.recurring,
          ),
          _MoreTile(
            icon: Icons.shopping_basket_outlined,
            title: tr('Bazar list'),
            subtitle: tr('A shopping list with prices'),
            route: AppRoutes.bazar,
          ),
          _Heading(tr('Trips and sharing')),
          _MoreTile(
            icon: Icons.luggage_outlined,
            title: tr('Trips & events'),
            subtitle: tr('What a trip or an occasion cost'),
            route: AppRoutes.tags,
          ),
          _MoreTile(
            icon: Icons.call_split,
            title: tr('Split a bill'),
            subtitle: tr('Share a bill with friends'),
            route: AppRoutes.splitBill,
          ),
          _Heading(tr('Faith')),
          _MoreTile(
            icon: Icons.volunteer_activism_outlined,
            title: tr('Zakat'),
            subtitle: tr('How much zakat is due'),
            route: AppRoutes.zakat,
          ),
          _Heading(tr('For fun')),
          _MoreTile(
            icon: Icons.auto_awesome_outlined,
            title: tr('Month wrapped'),
            subtitle: tr('Your month as a short story'),
            route: AppRoutes.wrapped(),
          ),
          _MoreTile(
            icon: Icons.emoji_events_outlined,
            title: tr('Badges'),
            subtitle: tr('Streaks and rewards'),
            route: AppRoutes.badges,
          ),
          _Heading(tr('Setup')),
          _MoreTile(
            icon: Icons.category_outlined,
            title: tr('Categories'),
            subtitle: tr('Food, transport and the rest'),
            route: AppRoutes.categories,
          ),
          _MoreTile(
            icon: Icons.backup_outlined,
            title: tr('Backup & export'),
            subtitle: tr('Keep your data safe'),
            route: AppRoutes.backup,
          ),
          _MoreTile(
            icon: Icons.notifications_outlined,
            title: tr('Notifications'),
            subtitle: tr('What was sent and what is coming'),
            route: AppRoutes.notifications,
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: tr('Settings'),
            subtitle: tr('Language, look and alerts'),
            route: AppRoutes.settings,
          ),
        ],
      ),
    );
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
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    this.highlighted = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  /// The Help tile stands out, so a new person finds it first.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tile = ListTile(
      leading: Icon(icon, color: highlighted ? colors.primary : null),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
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
