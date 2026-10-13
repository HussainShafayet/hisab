import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/goals/data/goals_repository.dart';

/// What was entered in the dialog: always above zero. The caller makes it
/// negative for money taken out.
typedef GoalMoney = ({int amount, DateTime date, String note});

/// Asks how much to put into a goal ([putIn]) or take out of it, on which
/// day, with an optional note. Null when cancelled.
Future<GoalMoney?> showGoalMoneyDialog(
  BuildContext context, {
  required bool putIn,
  required DateTime today,
}) {
  return showDialog<GoalMoney>(
    context: context,
    builder: (context) => _GoalMoneyDialog(putIn: putIn, today: today),
  );
}

class _GoalMoneyDialog extends StatefulWidget {
  const _GoalMoneyDialog({required this.putIn, required this.today});

  final bool putIn;
  final DateTime today;

  @override
  State<_GoalMoneyDialog> createState() => _GoalMoneyDialogState();
}

class _GoalMoneyDialogState extends State<_GoalMoneyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day = dateOnly(widget.today);

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = dateOnly(widget.today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = parseTakaToPoisha(_amount.text);
    if (amount == null || amount <= 0) return;
    Navigator.of(context)
        .pop((amount: amount, date: _day, note: _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.putIn ? tr('Put money in') : tr('Take money out')),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneyFormField(
                key: const ValueKey('goal-money-amount'),
                controller: _amount,
                label: tr('Amount'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('goal-money-note'),
                controller: _note,
                maxLength: GoalsRepository.maxNoteLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tr('Note (optional)')),
              ),
              const SizedBox(height: 4),
              DayField(label: tr('Date'), value: _day, onPick: _pickDay),
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
          key: const ValueKey('goal-money-save'),
          onPressed: _submit,
          child: Text(tr('Save')),
        ),
      ],
    );
  }
}
