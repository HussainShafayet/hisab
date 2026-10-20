import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/date_labels.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/transactions/domain/add_transaction_options.dart';
import 'package:hishab/features/transactions/domain/quick_entry.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// One line at the top of the add form: type `rickshaw 50` or `bazar 450
/// bkash`, see what it understood, and fill the form with it.
class QuickTypeBar extends StatefulWidget {
  const QuickTypeBar({
    required this.options,
    required this.onApply,
    required this.today,
    super.key,
  });

  final AddTransactionOptions options;

  /// The day today is, so the line can say "yesterday".
  final DateTime today;
  final ValueChanged<QuickEntry> onApply;

  @override
  State<QuickTypeBar> createState() => _QuickTypeBarState();
}

class _QuickTypeBarState extends State<QuickTypeBar> {
  final _controller = TextEditingController();
  QuickEntry? _entry;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String text) {
    final entry = parseQuickEntry(text, widget.options, today: widget.today);
    setState(() => _entry = entry.isEmpty ? null : entry);
  }

  void _apply() {
    final entry = _entry;
    if (entry == null) return;
    widget.onApply(entry);
    _controller.clear();
    setState(() => _entry = null);
  }

  @override
  Widget build(BuildContext context) {
    final entry = _entry;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const ValueKey('quick-type-field'),
          controller: _controller,
          textInputAction: TextInputAction.done,
          onChanged: _changed,
          onSubmitted: (_) => _apply(),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.bolt),
            hintText: tr('Type it in one line: rickshaw 50'),
            suffixIcon: IconButton(
              key: const ValueKey('quick-type-apply'),
              tooltip: tr('Fill the form'),
              icon: const Icon(Icons.check),
              onPressed: entry == null ? null : _apply,
            ),
          ),
        ),
        if (entry != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              key: const ValueKey('quick-type-preview'),
              spacing: 6,
              runSpacing: 6,
              children: [
                if (entry.type == TransactionType.income)
                  _Pill(tr('Income'), theme),
                _Pill(
                  entry.amount == null
                      ? tr('No amount yet')
                      : formatPoisha(entry.amount!),
                  theme,
                ),
                if (entry.category != null)
                  _Pill(tr(entry.category!.name), theme),
                if (entry.account != null)
                  _Pill(tr(entry.account!.name), theme),
                if (entry.day != null)
                  _Pill(dayLabel(entry.day!, widget.today), theme),
              ],
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
