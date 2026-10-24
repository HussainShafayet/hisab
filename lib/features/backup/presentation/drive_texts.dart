import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/backup/data/drive_gateway.dart';

/// What to tell the person about a problem with Google Drive. Null for a
/// sign-in that was closed: they did that themselves.
String? driveProblemText(DriveProblem problem, [String? detail]) {
  final text = switch (problem) {
    DriveProblem.cancelled => null,
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
  if (text == null) return null;
  return detail == null || detail.isEmpty ? text : '$text ($detail)';
}
