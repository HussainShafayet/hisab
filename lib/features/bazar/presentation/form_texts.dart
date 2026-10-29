import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';
import 'package:hishab/features/bazar/data/form_inbox_service.dart';

/// What to tell the person about a problem reading the answers of the form.
String formProblemText(FormInboxProblem problem, [String? detail]) {
  final text = switch (problem) {
    FormInboxProblem.noInternet => tr(
      'No internet. Check your connection and try again.',
    ),
    FormInboxProblem.notPublished => tr(
      'Google did not show the sheet. In the sheet choose File > Share > '
      'Publish to web > CSV and use that link.',
    ),
    FormInboxProblem.failed => tr('The sheet could not be read.'),
  };
  return detail == null || detail.isEmpty ? text : '$text ($detail)';
}

/// What a sync did, in a line for the person.
String formResultText(FormInboxResult result) => result.added == 0
    ? tr('No new items in the form.')
    : plural(
        result.added,
        'Added 1 item from the form.',
        'Added {n} items from the form.',
      );
