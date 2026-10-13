import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

/// What was entered for an item.
typedef BazarItemEdit = ({String name, int quantity, int? price});

/// Edits [item]: its name, how many, and the price of one. Null when
/// cancelled.
Future<BazarItemEdit?> showBazarItemDialog(
  BuildContext context,
  ShoppingItem item,
) {
  return showDialog<BazarItemEdit>(
    context: context,
    builder: (context) => _BazarItemDialog(item: item),
  );
}

class _BazarItemDialog extends StatefulWidget {
  const _BazarItemDialog({required this.item});

  final ShoppingItem item;

  @override
  State<_BazarItemDialog> createState() => _BazarItemDialogState();
}

class _BazarItemDialogState extends State<_BazarItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item.name);
  late final _quantity = TextEditingController(text: '${widget.item.quantity}');
  late final _price = TextEditingController(
    text: widget.item.price == null ? '' : poishaToInput(widget.item.price!),
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final price = _price.text.trim().isEmpty
        ? null
        : parseTakaToPoisha(_price.text);
    Navigator.of(context).pop((
      name: _name.text.trim(),
      quantity: int.parse(_quantity.text.trim()),
      price: price,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('Edit item')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('item-name'),
                controller: _name,
                maxLength: maxItemNameLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Name')),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? tr('Enter a name.') : null,
              ),
              TextFormField(
                key: const ValueKey('item-quantity'),
                controller: _quantity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(labelText: tr('How many')),
                validator: (value) {
                  final n = int.tryParse((value ?? '').trim());
                  return n == null || n < 1 || n > maxItemQuantity
                      ? tr('Enter a number from 1 to {max}', {
                          'max': maxItemQuantity,
                        })
                      : null;
                },
              ),
              const SizedBox(height: 8),
              MoneyFormField(
                key: const ValueKey('item-price'),
                controller: _price,
                label: tr('Price of one (optional)'),
                isRequired: false,
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
          key: const ValueKey('item-save'),
          onPressed: _submit,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
