import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';

/// What a form's text fields held when it opened, so the form can tell whether
/// the person has typed anything since. Make it once the fields are filled in.
class TextSnapshot {
  TextSnapshot(this._fields) : _start = _read(_fields);

  final List<TextEditingController> _fields;
  final List<String> _start;

  static List<String> _read(List<TextEditingController> fields) => [
    for (final field in fields) field.text.trim(),
  ];

  /// Whether any field differs from what it held at the start.
  bool get changed {
    final now = _read(_fields);
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _start[i]) return true;
    }
    return false;
  }

  /// Fires when any of the fields changes.
  Listenable get listenable => Listenable.merge(_fields);
}

/// Wraps a form: when the person goes back with something typed, asks before
/// the typing is thrown away. With nothing typed, going back is immediate.
/// Saving closes the form by code, which is never asked about.
class DiscardGuard extends StatelessWidget {
  const DiscardGuard({required this.snapshot, required this.child, super.key});

  final TextSnapshot snapshot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: snapshot.listenable,
      child: child,
      builder: (context, child) => PopScope(
        canPop: !snapshot.changed,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final leave = await confirmDiscard(context);
          if (leave && context.mounted) context.pop();
        },
        child: child!,
      ),
    );
  }
}

/// Asks whether to leave and lose what was typed. True to leave.
Future<bool> confirmDiscard(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const ValueKey('discard-dialog'),
      title: Text(tr('Leave without saving?')),
      content: Text(tr('What you typed here will be lost.')),
      actions: [
        TextButton(
          key: const ValueKey('discard-keep'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(tr('Keep editing')),
        ),
        FilledButton(
          key: const ValueKey('discard-leave'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(tr('Leave')),
        ),
      ],
    ),
  );
  return leave ?? false;
}
