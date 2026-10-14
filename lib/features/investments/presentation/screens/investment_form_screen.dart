import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/investments/data/investments_repository.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/features/investments/presentation/providers/investments_providers.dart';

/// Adds an investment, or changes the name, note and start day of one.
class InvestmentFormScreen extends ConsumerWidget {
  const InvestmentFormScreen({this.investmentId, super.key});

  /// Null to add a new one.
  final int? investmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = investmentId;
    if (id == null) return const _InvestmentForm();

    final items = ref.watch(investmentsProvider);
    return items.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: describeError(error)),
      ),
      data: (list) {
        final found = list.where((i) => i.investment.id == id).firstOrNull;
        if (found == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: tr('Investment not found.')),
          );
        }
        return _InvestmentForm(initial: found.investment);
      },
    );
  }
}

class _InvestmentForm extends ConsumerStatefulWidget {
  const _InvestmentForm({this.initial});

  final Investment? initial;

  @override
  ConsumerState<_InvestmentForm> createState() => _InvestmentFormState();
}

class _InvestmentFormState extends ConsumerState<_InvestmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _note = TextEditingController(text: widget.initial?.note);
  late DateTime _startedOn =
      widget.initial?.startedOn ?? dateOnly(ref.read(clockProvider)());
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _startedOn.isAfter(today) ? today : _startedOn,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (picked != null && mounted) {
      setState(() => _startedOn = dateOnly(picked));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(investmentsRepositoryProvider);
    try {
      if (_isEditing) {
        await repository.updateInvestment(
          widget.initial!.id,
          name: _name.text,
          note: _note.text,
          startedOn: _startedOn,
        );
        if (mounted) context.pop();
      } else {
        final id = await repository.createInvestment(
          name: _name.text,
          note: _note.text,
          startedOn: _startedOn,
        );
        // Straight to the page where the money is added.
        if (mounted) context.pushReplacement(AppRoutes.investment(id));
      }
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Edit investment') : tr('New investment')),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const ValueKey('investment-name'),
                    controller: _name,
                    autofocus: !_isEditing,
                    textCapitalization: TextCapitalization.words,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        InvestmentsRepository.maxNameLength,
                      ),
                    ],
                    decoration: InputDecoration(
                      labelText: tr('Name'),
                      helperText: tr('Like "Rahim\'s shop" or "Poultry farm".'),
                    ),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? tr('Enter a name')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('investment-form-note'),
                    controller: _note,
                    maxLength: InvestmentsRepository.maxNoteLength,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: tr('Note (optional)'),
                      helperText: tr('Who you are in it with, what share.'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DayField(
                    label: tr('Started on'),
                    value: _startedOn,
                    onPick: _pickDay,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('investment-form-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _isEditing ? tr('Save changes') : tr('Add investment'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
