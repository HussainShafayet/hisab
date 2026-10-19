import 'package:hishab/core/l10n/translator.dart';

/// The kinds of notification the app sends. Each has its own channel on the
/// phone (so each can be muted on its own) and its own funny sound.
enum AlertKind {
  /// A bill or a recurring item is due.
  bill('bill', 'alert_uhoh'),

  /// A loan is due.
  loan('loan', 'alert_coin'),

  /// "Did you write today's entries?"
  daily('daily', 'alert_boing'),

  /// 85% of the month's budget is used.
  budgetNear('budget_near', 'alert_uhoh'),

  /// The month's budget is crossed.
  budgetOver('budget_over', 'alert_wah'),

  /// The same kind of spending keeps happening.
  habit('habit', 'alert_horn'),

  /// The wrapped of the month is ready.
  wrapped('wrapped', 'alert_tada'),

  /// Zakat day. Calm, no jokes.
  zakat('zakat', 'alert_chime');

  const AlertKind(this.channelId, this.sound);

  /// The channel on the phone. The funny-sound twin adds `_fun`: a channel's
  /// sound cannot be changed once it exists, so the two are separate.
  final String channelId;

  /// The file in `android/app/src/main/res/raw` (without `.wav`).
  final String sound;

  /// The channel's name, as the phone's settings show it.
  String get label => switch (this) {
    AlertKind.bill => tr('Bill reminders'),
    AlertKind.loan => tr('Loan reminders'),
    AlertKind.daily => tr('Daily reminder to write'),
    AlertKind.budgetNear => tr('Budget almost used'),
    AlertKind.budgetOver => tr('Budget crossed'),
    AlertKind.habit => tr('Habit alerts'),
    AlertKind.wrapped => tr('Month wrapped'),
    AlertKind.zakat => tr('Zakat day'),
  };
}
