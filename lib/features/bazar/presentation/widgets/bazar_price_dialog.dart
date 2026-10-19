import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

/// What was entered for a remembered price.
typedef BazarPriceEdit = ({String name, int price});

/// Adds a remembered price, or changes [price]. Null when cancelled.
Future<BazarPriceEdit?> showBazarPriceDialog(
  BuildContext context, {
  RememberedPrice? price,
}) {
  return showDialog<BazarPriceEdit>(
    context: context,
    builder: (context) => _BazarPriceDialog(price: price),
  );
}

class _BazarPriceDialog extends StatefulWidget {
  const _BazarPriceDialog({required this.price});

  final RememberedPrice? price;

  @override
  State<_BazarPriceDialog> createState() => _BazarPriceDialogState();
}

class _BazarPriceDialogState extends State<_BazarPriceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.price?.name ?? '');
  late final _price = TextEditingController(
    text: switch (widget.price?.price) {
      final price? => poishaToInput(price),
      null => '',
    },
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop((name: _name.text.trim(), price: parseTakaToPoisha(_price.text)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.price == null ? tr('Add a price') : tr('Edit price')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('price-name'),
                controller: _name,
                maxLength: maxItemNameLength,
                autofocus: widget.price == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Name')),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? tr('Enter a name.') : null,
              ),
              const SizedBox(height: 8),
              MoneyFormField(
                key: const ValueKey('price-amount'),
                controller: _price,
                label: tr('Price of one'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('price-save'),
          onPressed: _submit,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
