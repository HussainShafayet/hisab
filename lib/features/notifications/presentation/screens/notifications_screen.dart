import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/notifications/alert_kind.dart';
import 'package:hishab/core/notifications/alert_route.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/motion.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:hishab/features/notifications/domain/logged_notification.dart';
import 'package:hishab/features/notifications/presentation/providers/notification_providers.dart';
import 'package:intl/intl.dart';

/// What the app has told you, and what it will tell you: the notifications
/// that showed (newest first) and the ones set to show later.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(notificationsProvider);
    final hasSent = lists.value?.sent.isNotEmpty ?? false;
    final hasUnseen = lists.value?.sent.any((n) => !n.seen) ?? false;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Notifications')),
          actions: [
            if (hasUnseen)
              IconButton(
                key: const ValueKey('mark-all-read'),
                tooltip: tr('Mark all as read'),
                icon: const Icon(Icons.done_all),
                onPressed: () => ref
                    .read(notificationLogRepositoryProvider)
                    .markAllSeen(ref.read(clockProvider)()),
              ),
            if (hasSent)
              IconButton(
                key: const ValueKey('clear-notifications'),
                tooltip: tr('Clear history'),
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _clear(context, ref),
              ),
            const HelpButton('alerts'),
          ],
          bottom: TabBar(
            tabs: [
              Tab(key: const ValueKey('tab-sent'), text: tr('Sent')),
              Tab(key: const ValueKey('tab-upcoming'), text: tr('Coming up')),
            ],
          ),
        ),
        body: lists.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(message: describeError(error)),
          data: (data) => TabBarView(
            children: [
              _NotificationList(
                listKey: 'notifications-sent',
                items: data.sent,
                empty: EmptyState(
                  icon: Icons.notifications_none,
                  title: tr('Nothing sent yet'),
                  message: tr(
                    'Alerts and reminders will show up here once they have '
                    'come.',
                  ),
                ),
                footnote: tr(
                  'Reminders are listed once their time has passed. If '
                  'notifications were blocked on your phone, they did not '
                  'show.',
                ),
              ),
              _NotificationList(
                listKey: 'notifications-upcoming',
                items: data.upcoming,
                empty: EmptyState(
                  icon: Icons.schedule,
                  title: tr('Nothing coming up'),
                  message: tr(
                    'Bills, loans, the daily reminder and the zakat day '
                    'appear here before their time.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Clear the history?')),
        content: Text(
          tr(
            'The notifications that were sent are removed from this list. '
            'The ones coming up stay.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          FilledButton(
            key: const ValueKey('confirm-clear-notifications'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Clear')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(notificationLogRepositoryProvider)
          .clearShown(ref.read(clockProvider)());
      messenger.showMessage(tr('History cleared'));
    } on Object catch (error) {
      messenger.showError(describeError(error));
    }
  }
}

/// One tab: the notifications under a heading for their day.
class _NotificationList extends ConsumerWidget {
  const _NotificationList({
    required this.listKey,
    required this.items,
    required this.empty,
    this.footnote,
  });

  final String listKey;
  final List<LoggedNotification> items;
  final Widget empty;
  final String? footnote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return KeyedSubtree(key: ValueKey(listKey), child: empty);
    }
    final now = ref.read(clockProvider)();
    final theme = Theme.of(context);

    final children = <Widget>[];
    var arrived = 0;
    DateTime? day;
    for (final item in items) {
      final itemDay = dateOnly(item.at);
      if (day == null || !isSameDay(day, itemDay)) {
        day = itemDay;
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              dayLabel(itemDay, now),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      children.add(
        arriving(
          arrived++,
          _NotificationTile(
            item,
            shown: !item.at.isAfter(now),
            onTap: () {
              if (!item.seen && !item.at.isAfter(now)) {
                ref.read(notificationLogRepositoryProvider).markSeen(item.id);
              }
              openRoute(context, routeForAlert(item.kind));
            },
          ),
        ),
      );
    }
    if (footnote != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            footnote!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView(
      key: ValueKey(listKey),
      padding: const EdgeInsets.only(bottom: 24),
      children: children,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile(
    this.item, {
    required this.shown,
    required this.onTap,
  });

  final LoggedNotification item;

  /// It has shown already (it is not one that is still to come).
  final bool shown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unseen = shown && !item.seen;
    return ListTile(
      key: ValueKey('notification-${item.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        foregroundColor: theme.colorScheme.onSecondaryContainer,
        child: Icon(_iconOf(item.kind)),
      ),
      title: Text(
        item.title,
        style: unseen ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(item.body),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            localizeDigits(DateFormat('h:mm a').format(item.at)),
            style: theme.textTheme.labelMedium,
          ),
          if (unseen)
            Container(
              key: ValueKey('unseen-dot-${item.id}'),
              margin: const EdgeInsets.only(top: 6),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

IconData _iconOf(AlertKind kind) => switch (kind) {
  AlertKind.bill => Icons.receipt_long_outlined,
  AlertKind.loan => Icons.handshake_outlined,
  AlertKind.daily => Icons.edit_note,
  AlertKind.budgetNear => Icons.pie_chart_outline,
  AlertKind.budgetOver => Icons.warning_amber_rounded,
  AlertKind.habit => Icons.repeat,
  AlertKind.wrapped => Icons.auto_awesome_outlined,
  AlertKind.zakat => Icons.volunteer_activism_outlined,
};
