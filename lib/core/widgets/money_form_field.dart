import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hishab/core/utils/money.dart';

/// A text field for an amount in taka. Typed text is read back with
/// `parseTakaToPoisha`.
class MoneyFormField extends StatelessWidget {
  const MoneyFormField({
    required this.controller,
    required this.label,
    this.allowNegative = false,
    this.isRequired = true,
    this.autofocus = false,
    this.onChanged,
    this.helperText,
    super.key,
  });

  final TextEditingController controller;
  final String label;
  final bool allowNegative;

  /// When false, an empty field is valid.
  final bool isRequired;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      keyboardType: TextInputType.numberWithOptions(
        decimal: true,
        signed: allowNegative,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          RegExp(allowNegative ? r'[0-9.,\-]' : r'[0-9.,]'),
        ),
      ],
      decoration: InputDecoration(
        labelText: label,
        prefixText: '৳ ',
        helperText: helperText,
      ),
      validator: (value) {
        final text = value?.trim() ?? '';
        if (text.isEmpty) return isRequired ? 'Enter an amount' : null;
        if (parseTakaToPoisha(text) == null) {
          return 'Enter a valid amount, like 1500 or 1500.50';
        }
        return null;
      },
    );
  }
}
