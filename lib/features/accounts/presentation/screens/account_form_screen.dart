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
import 'package:hishab/features/accounts/domain/account_suggestions.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/accounts/presentation/widgets/account_card.dart';
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

  /// The account as it will look, for the card at the top.
  Account get _preview => Account(
    id: widget.initial?.id ?? 0,
    name: _name.text.trim().isEmpty ? 'Account name' : _name.text.trim(),
    type: _type,
    openingBalance: parseTakaToPoisha(_openingBalance.text) ?? 0,
    includeInTotal: _includeInTotal,
    isArchived: false,
  );

  void _useSuggestion(String name) {
    setState(() {
      _name.value = TextEditingValue(
        text: name,
        selection: TextSelection.collapsed(offset: name.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typedName = _name.text.trim().toLowerCase();
    final suggestions = [
      for (final name in accountNameSuggestions(_type))
        if (name.toLowerCase() != typedName) name,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit account' : 'New account')),
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
                  // How the account will look. Editing shows no balance: the
                  // opening balance is only part of it.
                  AccountCard(
                    key: const ValueKey('account-preview'),
                    account: _preview,
                    balance: _isEditing ? null : _preview.openingBalance,
                  ),
                  const SizedBox(height: 24),
                  Text('Kind of account', style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  for (var i = 0; i < AccountType.values.length; i += 2)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          for (final type in AccountType.values.skip(i).take(2))
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: type == AccountType.values[i] ? 6 : 0,
                                  left: type == AccountType.values[i] ? 0 : 6,
                                ),
                                child: _TypeTile(
                                  type: type,
                                  selected: _type == type,
                                  onTap: () => setState(() => _type = type),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setState(() {}),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(
                        AccountsRepository.maxNameLength,
                      ),
                    ],
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Enter a name' : null,
                  ),
                  if (!_isEditing && suggestions.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 0,
                      children: [
                        for (final name in suggestions)
                          ActionChip(
                            key: ValueKey('suggestion-$name'),
                            label: Text(name),
                            onPressed: () => _useSuggestion(name),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  MoneyFormField(
                    controller: _openingBalance,
                    label: 'Opening balance',
                    allowNegative: true,
                    isRequired: false,
                    onChanged: (_) => setState(() {}),
                    helperText:
                        'What the account held when you started. '
                        'Leave empty for 0.',
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include in total balance'),
                    subtitle: const Text(
                      'Turn off for money you do not want counted, like '
                      'savings.',
                    ),
                    value: _includeInTotal,
                    onChanged: (value) =>
                        setState(() => _includeInTotal = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
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
                  onPressed: _saving ? null : _save,
                  child: Text(_isEditing ? 'Save changes' : 'Add account'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One kind of account to choose from: its color and icon, and a check when
/// chosen.
class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final AccountType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: type.label,
      child: InkWell(
        key: ValueKey('type-${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? scheme.primaryContainer : null,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: type.color,
                child: Icon(type.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  type.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: selected ? FontWeight.w600 : null),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
