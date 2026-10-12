import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:intl/intl.dart';

/// A day that can be picked, and cleared when it is optional.
class DayField extends StatelessWidget {
  const DayField({
    required this.label,
    required this.value,
    required this.onPick,
    this.onClear,
    super.key,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;

  /// Shown as a clear button when [value] is set. Null for a required day.
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = value;
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: day != null && onClear != null
              ? IconButton(
                  tooltip: tr('Clear'),
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 20),
        ),
        child: Text(
          day == null ? tr('Not set') : DateFormat('d MMM yyyy').format(day),
          style: day == null
              ? theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
