import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The "More" tab: entry points to everything that is not a main tab.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: const [
          _MoreTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Accounts',
            route: AppRoutes.accounts,
          ),
          _MoreTile(
            icon: Icons.category_outlined,
            title: 'Categories',
            route: AppRoutes.categories,
          ),
          _MoreTile(
            icon: Icons.backup_outlined,
            title: 'Backup & export',
            route: AppRoutes.backup,
          ),
          _MoreTile(
            icon: Icons.settings_outlined,
            title: 'Settings',
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
