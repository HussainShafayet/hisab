import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';

/// The two links of a Google Form: of its published answers, and of the form.
typedef FormLinks = ({String sheet, String form});

/// Asks for the link of the published sheet of a Google Form, and, if the person
/// likes, the link of the form itself. Null when cancelled.
Future<FormLinks?> showFormLinkDialog(BuildContext context) =>
    showDialog<FormLinks>(
      context: context,
      builder: (context) => const _FormLinkDialog(),
    );

class _FormLinkDialog extends StatefulWidget {
  const _FormLinkDialog();

  @override
  State<_FormLinkDialog> createState() => _FormLinkDialogState();
}

class _FormLinkDialogState extends State<_FormLinkDialog> {
  final _sheet = TextEditingController();
  final _form = TextEditingController();

  @override
  void dispose() {
    _sheet.dispose();
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Add from a Google Form')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                'Make a Google Form with one long-answer question, "Item", '
                'and link it to a sheet (Responses > Link to Sheets). In that '
                'sheet choose File > Share > Publish to web > CSV, and paste '
                'the link here. One answer can hold many things, one on each '
                'line. Whoever has the form can add to your list.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('form-sheet-link'),
              controller: _sheet,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Link of the published sheet'),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('form-link'),
              controller: _form,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: tr('Link of the form (to send to others, optional)'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('form-link-ok'),
          onPressed: () =>
              Navigator.of(context)
                  .pop((sheet: _sheet.text.trim(), form: _form.text.trim())),
          child: Text(tr('Add')),
        ),
      ],
    );
  }
}
