import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The "More" tab: entry points to everything that is not a main tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('More'))),
      body: ListView(
        children: [
          _MoreTile(
            icon: Icons.account_balance_wallet_outlined,
            title: tr('Accounts'),
            route: AppRoutes.accounts,
          ),
          _MoreTile(
            icon: Icons.savings_outlined,
            title: tr('Savings goals'),
            route: AppRoutes.goals,
          ),
          _MoreTile(
            icon: Icons.shopping_basket_outlined,
            title: tr('Bazar list'),
            route: AppRoutes.bazar,
          ),
          _MoreTile(
            icon: Icons.luggage_outlined,
            title: tr('Trips & events'),
            route: AppRoutes.tags,
          ),
          _MoreTile(
            icon: Icons.repeat,
            title: tr('Recurring'),
            route: AppRoutes.recurring,
          ),
          _MoreTile(
            icon: Icons.handshake_outlined,
            title: tr('Loans'),
            route: AppRoutes.debts,
          ),
          _MoreTile(
            icon: Icons.call_split,
            title: tr('Split a bill'),
            route: AppRoutes.splitBill,
          ),
          _MoreTile(
            icon: Icons.volunteer_activism_outlined,
            title: tr('Zakat'),
            route: AppRoutes.zakat,
          ),
          _MoreTile(
            icon: Icons.category_outlined,
            title: tr('Categories'),
            route: AppRoutes.categories,
          ),
          _MoreTile(
            icon: Icons.backup_outlined,
            title: tr('Backup & export'),
            route: AppRoutes.backup,
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: tr('Settings'),
            route: AppRoutes.settings,
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.title,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String route;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
  }
}
