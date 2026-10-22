import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a message stays, and an error a little longer to be read.
const messageDuration = Duration(seconds: 4);
const errorDuration = Duration(seconds: 7);

/// How long "Undo" stays after something was deleted: long enough to notice
/// it and to reach for the button.
const undoDuration = Duration(seconds: 8);

/// The snack bars of the app. A plain `SnackBar` with an action (like "Undo")
/// stays on screen until it is dismissed, which is not what anyone wants for a
/// passing message. These hide by themselves, also with an action, and always
/// have a close button. A new one replaces the one on screen, so messages do
/// not queue up.
extension AppSnackBars on ScaffoldMessengerState {
  /// A short message, with an optional [action] such as "Undo".
  void showMessage(
    String text, {
    SnackBarAction? action,
    Duration duration = messageDuration,
  }) => _show(Text(text), action: action, duration: duration);

  /// What went wrong, in words the person can read, with a warning icon.
  void showError(String text) => _show(
    Builder(
      builder: (context) {
        final color = DefaultTextStyle.of(context).style.color;
        return Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(text)),
          ],
        );
      },
    ),
    duration: errorDuration,
  );

  void _show(
    Widget content, {
    required Duration duration,
    SnackBarAction? action,
  }) {
    hideCurrentSnackBar();
    showSnackBar(
      SnackBar(
        content: content,
        action: action,
        duration: duration,
        // By default a snack bar with an action never goes away by itself.
        persist: false,
        showCloseIcon: true,
      ),
    );
  }
}

/// The key of the app's [ScaffoldMessenger], so a message can be shown from
/// outside any screen: an error that nothing else caught (see `main`). One for
/// each app, not shared between them.
final rootMessengerKeyProvider = Provider<GlobalKey<ScaffoldMessengerState>>(
  (ref) => GlobalKey<ScaffoldMessengerState>(),
);
