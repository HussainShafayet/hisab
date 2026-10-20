import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/notifications/presentation/providers/notification_providers.dart';

/// The bell in the app bar: a number on it for the notifications that have
/// not been opened, and a tap opens the list.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unseenNotificationsProvider).value ?? 0;
    return IconButton(
      key: const ValueKey('notification-bell'),
      tooltip: tr('Notifications'),
      icon: Badge(
        key: const ValueKey('notification-badge'),
        isLabelVisible: count > 0,
        label: Text(localizeDigits(count > 99 ? '99+' : '$count')),
        child: Icon(
          count > 0 ? Icons.notifications : Icons.notifications_outlined,
        ),
      ),
      onPressed: () => context.push(AppRoutes.notifications),
    );
  }
}
