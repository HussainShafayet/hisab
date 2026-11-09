import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';

/// What to tell the person about a problem with Google Drive. A sign-in that
/// stops is told too: Google ends one it does not trust (an app key it does not
/// know) the same way as a closed window, and saying nothing left the switch
/// off with no reason.
String? driveProblemText(DriveProblem problem, [String? detail]) {
  final text = switch (problem) {
    DriveProblem.cancelled => tr(
      'Google sign-in did not finish, so Google Drive backup is still off. '
      'If you did choose an account, Google may not know this copy of the '
      'app yet: its signing key must be added in Google Cloud.',
    ),
    DriveProblem.needsSignIn => tr('Sign in to Google again.'),
    DriveProblem.noInternet => tr(
      'No internet. Check your connection and try again.',
    ),
    DriveProblem.notAllowed => tr(
      'Google did not allow it. Check that the Drive API is on and the app is '
      'published in Google Cloud.',
    ),
    DriveProblem.failed => tr('Google Drive did not take the file.'),
  };
  return detail == null || detail.isEmpty ? text : '$text ($detail)';
}

/// How long ago [then] was, for a line like "Saved 5 Nov, 3:30 pm (2 hours
/// ago)".
String agoText(DateTime then, DateTime now) {
  final gap = now.difference(then);
  if (gap.inMinutes < 1) return tr('just now');
  if (gap.inHours < 1) {
    return plural(gap.inMinutes, '1 minute ago', '{n} minutes ago');
  }
  if (gap.inDays < 1) {
    return plural(gap.inHours, '1 hour ago', '{n} hours ago');
  }
  return plural(gap.inDays, '1 day ago', '{n} days ago');
}
