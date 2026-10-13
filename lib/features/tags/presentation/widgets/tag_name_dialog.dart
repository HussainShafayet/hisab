import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/tags/domain/tag.dart';

/// Asks for the name of a tag. [onSave] makes or renames the tag; if it throws
/// a [ValidationException] the message is shown in the dialog and the name can
/// be fixed. Returns true once saved, null when cancelled.
Future<bool?> showTagNameDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function(String name) onSave,
  String initial = '',
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) =>
        _TagNameDialog(title: title, initial: initial, onSave: onSave),
  );
}

class _TagNameDialog extends StatefulWidget {
  const _TagNameDialog({
    required this.title,
    required this.initial,
    required this.onSave,
  });

  final String title;
  final String initial;
  final Future<void> Function(String name) onSave;

  @override
  State<_TagNameDialog> createState() => _TagNameDialogState();
}

class _TagNameDialogState extends State<_TagNameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_name.text);
      if (mounted) Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const ValueKey('tag-name'),
        controller: _name,
        autofocus: true,
        maxLength: maxTagNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: tr('Name'),
          hintText: tr("Cox's Bazar trip, Eid..."),
          errorText: _error,
        ),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _saving ? null : _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('tag-save'),
          onPressed: _saving ? null : _submit,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
