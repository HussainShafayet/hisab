import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/data/accounts_repository.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_type_ui.dart';

/// Creates an account, or edits the one with [accountId].
class AccountFormScreen extends ConsumerWidget {
  const AccountFormScreen({this.accountId, super.key});

  final int? accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = accountId;
    if (id == null) return const _AccountForm();

    return ref
        .watch(accountProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('Edit account')),
            body: const LoadingView(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: const Text('Edit account')),
            body: ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(accountProvider(id)),
            ),
          ),
          data: (account) => account == null
              ? Scaffold(
                  appBar: AppBar(title: const Text('Edit account')),
                  body: const ErrorView(
                    message: 'This account no longer exists.',
                  ),
                )
              : _AccountForm(initial: account),
        );
  }
}

class _AccountForm extends ConsumerStatefulWidget {
  const _AccountForm({this.initial});

  final Account? initial;

  @override
  ConsumerState<_AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<_AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _openingBalance = TextEditingController(
    text: widget.initial == null || widget.initial!.openingBalance == 0
        ? ''
        : poishaToInput(widget.initial!.openingBalance),
  );
  late AccountType _type = widget.initial?.type ?? AccountType.cash;
  late bool _includeInTotal = widget.initial?.includeInTotal ?? true;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.initial != null;

  @override
  void dispose() {
    _name.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    final repository = ref.read(accountsRepositoryProvider);
    final openingBalance = parseTakaToPoisha(_openingBalance.text) ?? 0;
    try {
      if (_isEditing) {
        await repository.updateAccount(
          widget.initial!.id,
          name: _name.text,
          type: _type,
          openingBalance: openingBalance,
          includeInTotal: _includeInTotal,
        );
      } else {
        await repository.createAccount(
          name: _name.text,
          type: _type,
          openingBalance: openingBalance,
          includeInTotal: _includeInTotal,
        );
      }
      if (mounted) context.pop();
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit account' : 'New account')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            TextFormField(
              controller: _name,
              autofocus: !_isEditing,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                LengthLimitingTextInputFormatter(
                  AccountsRepository.maxNameLength,
                ),
              ],
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (value) =>
                  (value?.trim().isEmpty ?? true) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 24),
            Text('Type', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in AccountType.values)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: _type == type,
                    onSelected: (_) => setState(() => _type = type),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            MoneyFormField(
              controller: _openingBalance,
              label: 'Opening balance',
              allowNegative: true,
              isRequired: false,
              helperText:
                  'What the account held when you started. Leave empty for 0.',
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include in total balance'),
              subtitle: const Text(
                'Turn off for money you do not want counted, like savings.',
              ),
              value: _includeInTotal,
              onChanged: (value) => setState(() => _includeInTotal = value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_isEditing ? 'Save changes' : 'Add account'),
            ),
          ],
        ),
      ),
    );
  }
}
