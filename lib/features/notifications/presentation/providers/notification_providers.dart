import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/database/database_provider.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/features/notifications/data/notification_log_repository.dart';
import 'package:hishab/features/notifications/domain/logged_notification.dart';

final notificationLogRepositoryProvider = Provider<NotificationLogRepository>(
  (ref) => NotificationLogRepository(ref.watch(appDatabaseProvider)),
);

/// The history, split at the time the screen was opened.
final notificationsProvider = StreamProvider.autoDispose<NotificationLists>((
  ref,
) {
  final now = ref.read(clockProvider)();
  return ref
      .watch(notificationLogRepositoryProvider)
      .watchAll()
      .map((all) => splitNotifications(all, now));
});
