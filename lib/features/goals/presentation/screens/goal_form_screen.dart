import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/goals/domain/goal.dart';
import 'package:hishab/features/goals/presentation/providers/goals_providers.dart';
import 'package:hishab/features/goals/presentation/widgets/goal_icons.dart';
import 'package:hishab/core/widgets/discard_guard.dart';

/// Makes a goal, or edits the one with [goalId].
class GoalFormScreen extends ConsumerWidget {
  const GoalFormScreen({
    this.goalId,
    this.prefillName,
    this.prefillDay,
    this.prefillIcon,
    super.key,
  });

  final int? goalId;

  /// For a new goal: the name, the day and the icon to start with.
  final String? prefillName;
  final DateTime? prefillDay;
  final String? prefillIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = goalId;
    if (id == null) {
      return _GoalForm(
        prefillName: prefillName,
        prefillDay: prefillDay,
        prefillIcon: prefillIcon,
      );
    }
    final title = Text(tr('Edit goal'));
    return ref
        .watch(goalsProvider)
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: title),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: title),
            body: ErrorView(message: describeError(error)),
          ),
          data: (list) {
            final goal = list.where((g) => g.goal.id == id).firstOrNull;
            return goal == null
                ? Scaffold(
                    appBar: AppBar(title: title),
                    body: ErrorView(message: tr('This goal no longer exists.')),
                  )
                : _GoalForm(initial: goal.goal);
          },
        );
  }
}

class _GoalForm extends ConsumerStatefulWidget {
  const _GoalForm({
    this.initial,
    this.prefillName,
    this.prefillDay,
    this.prefillIcon,
  });

  final SavingsGoal? initial;
  final String? prefillName;
  final DateTime? prefillDay;
  final String? prefillIcon;

  @override
  ConsumerState<_GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<_GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.name ?? widget.prefillName ?? '',
  );
  late final _target = TextEditingController(
    text: widget.initial == null ? '' : poishaToInput(widget.initial!.target),
  );
  late DateTime? _day = widget.initial?.targetDate ?? widget.prefillDay;
  late String _icon =
      widget.initial?.icon ??
      (goalIcons.contains(widget.prefillIcon)
          ? widget.prefillIcon!
          : defaultGoalIcon);
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _day != null && !_day!.isBefore(today)
          ? _day!
          : today.add(const Duration(days: 30)),
      firstDate: today,
      lastDate: DateTime(today.year + 30),
    );
    if (picked != null && mounted) setState(() => _day = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(goalsRepositoryProvider);
    final target = parseTakaToPoisha(_target.text)!;
    try {
      if (_isEditing) {
        await repository.updateGoal(
          widget.initial!.id,
          name: _name.text,
          target: target,
          targetDate: _day,
          icon: _icon,
        );
      } else {
        await repository.createGoal(
          name: _name.text,
          target: target,
          targetDate: _day,
          icon: _icon,
        );
      }
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  /// What the text fields held on opening, to tell if anything was typed.
  late final _snapshot = TextSnapshot([_name, _target]);

  @override
  Widget build(BuildContext context) =>
      DiscardGuard(snapshot: _snapshot, child: _buildForm(context));

  Widget _buildForm(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Edit goal') : tr('New goal')),
      ),
      body: Column(
        children: [
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  TextFormField(
                    key: const ValueKey('goal-name'),
                    controller: _name,
                    autofocus: !_isEditing,
                    maxLength: 60,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr('What are you saving for?'),
                      hintText: tr('Laptop, Eid, trip...'),
                    ),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? tr('Enter a name.')
                        : null,
                  ),
                  const SizedBox(height: 8),
                  MoneyFormField(
                    key: const ValueKey('goal-target'),
                    controller: _target,
                    label: tr('Target'),
                    helperText: tr('How much you want to have in the end.'),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                  const SizedBox(height: 16),
                  DayField(
                    key: const ValueKey('goal-day'),
                    label: tr('Reach it by (optional)'),
                    value: _day,
                    onPick: _pickDay,
                    onClear: () => setState(() => _day = null),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      tr(
                        'With a day, Hishab tells you how much to put aside '
                        'each month.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(tr('Icon'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final key in goalIcons)
                        ChoiceChip(
                          key: ValueKey('goal-icon-$key'),
                          label: Icon(goalIconData(key), size: 22),
                          selected: _icon == key,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _icon = key),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      key: const ValueKey('form-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('goal-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? tr('Save changes') : tr('Add goal')),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
