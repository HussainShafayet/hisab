import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:intl/intl.dart';

/// A friendly message to send to someone who owes me [amount] (in poisha),
/// with the day it was due when there is one.
String loanReminderText({
  required String name,
  required int amount,
  DateTime? dueOn,
}) {
  final args = {'name': name, 'amount': formatPoisha(amount)};
  if (dueOn == null) {
    return tr(
      'Hi {name}, a quick reminder about the {amount} you owe me. '
      'Please send it when you can. Thanks!',
      args,
    );
  }
  return tr(
    'Hi {name}, a quick reminder about the {amount} you owe me, which was '
    'due on {date}. Please send it when you can. Thanks!',
    {...args, 'date': DateFormat('d MMM').format(dueOn)},
  );
}

/// Opens the share sheet with a reminder message, so it can be sent from
/// WhatsApp, Messenger, SMS and so on.
Future<void> shareLoanReminder(
  BuildContext context,
  WidgetRef ref, {
  required String name,
  required int amount,
  DateTime? dueOn,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref
        .read(fileGatewayProvider)
        .shareText(loanReminderText(name: name, amount: amount, dueOn: dueOn));
  } on Object {
    messenger.showSnackBar(
      SnackBar(content: Text(tr('Could not open the share sheet.'))),
    );
  }
}
