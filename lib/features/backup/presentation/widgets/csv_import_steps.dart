import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';
import 'package:intl/intl.dart';

/// A category of the file that the person matched with one of the app's.
class MatchedCategory {
  const MatchedCategory({
    required this.key,
    required this.fileLabel,
    required this.appLabel,
  });

  /// The key the plan matches the file's rows by (`categoryKey`).
  final String key;

  /// The category as the file names it.
  final String fileLabel;

  /// The category of the app it was matched with, with what it is inside.
  final String appLabel;
}

/// Asks for the name of a new account and whether it counts in the total
/// balance. Returns null when cancelled.
Future<({String name, bool includeInTotal})?> showNewAccountDialog(
  BuildContext context,
) {
  return showDialog<({String name, bool includeInTotal})>(
    context: context,
    builder: (context) => const _NewAccountDialog(),
  );
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _name = TextEditingController();
  bool _includeInTotal = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop((name: name, includeInTotal: _includeInTotal));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tr('New account')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('new-account-name'),
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: tr('Account name'),
              hintText: tr('For example: Old records'),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            key: const ValueKey('new-account-in-total'),
            contentPadding: EdgeInsets.zero,
            title: Text(tr('Count it in my total balance')),
            subtitle: Text(
              tr(
                'Turn this off for old records, so your total stays as it is.',
              ),
            ),
            value: _includeInTotal,
            onChanged: (value) => setState(() => _includeInTotal = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('Cancel')),
        ),
        FilledButton(
          key: const ValueKey('new-account-save'),
          onPressed: _save,
          child: Text(tr('Create account')),
        ),
      ],
    );
  }
}

/// The first step: choose the file.
class ImportChooseStep extends StatelessWidget {
  const ImportChooseStep({required this.error, super.key});

  /// Why the last file could not be used, if it could not.
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.upload_file_outlined,
          size: 64,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          tr('Import transactions from a CSV file'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'In Google Sheets or Excel, save your sheet as CSV (in Sheets: File, '
            'Download, Comma-separated values). Then choose that file here. '
            'You will say which column is which, and see a preview before '
            'anything is added.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            key: const ValueKey('import-error'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// The second step: say which column is which.
class ImportMapStep extends StatelessWidget {
  const ImportMapStep({
    required this.fileName,
    required this.table,
    required this.hasHeader,
    required this.mapping,
    required this.accounts,
    required this.onHasHeaderChanged,
    required this.onFieldChanged,
    required this.onDateFormatChanged,
    required this.onTypeSourceChanged,
    required this.onDefaultAccountChanged,
    required this.onCreateAccount,
    this.remembered = false,
    super.key,
  });

  final String fileName;
  final CsvTable table;
  final bool hasHeader;
  final ImportMapping mapping;

  /// The accounts that can be chosen as the default.
  final List<Account> accounts;

  final ValueChanged<bool> onHasHeaderChanged;
  final void Function(ImportField field, int? column) onFieldChanged;
  final ValueChanged<SheetDateFormat> onDateFormatChanged;
  final ValueChanged<TypeSource> onTypeSourceChanged;
  final ValueChanged<int?> onDefaultAccountChanged;
  final VoidCallback onCreateAccount;

  /// The columns were set the way they were for the last file like this.
  final bool remembered;

  /// The first non-empty cell of [column], to show what the column holds.
  String _sample(int column) {
    for (final row in table.rows) {
      if (row[column].isNotEmpty) {
        final text = row[column];
        return text.length > 24 ? '${text.substring(0, 24)}…' : text;
      }
    }
    return '';
  }

  String _dateExample() {
    final column = mapping.columnOf(ImportField.date);
    if (column == null) return '';
    final text = [
      for (final row in table.rows)
        if (row[column].isNotEmpty) row[column],
    ].firstOrNull;
    if (text == null) return tr('The date column is empty.');
    final date = parseSheetDate(text, mapping.dateFormat);
    return date == null
        ? tr('"{text}" cannot be read in this order.', {'text': text})
        : tr('"{text}" is {date}.', {
            'text': text,
            'date': DateFormat('d MMMM yyyy').format(date),
          });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAccountColumn = mapping.columnOf(ImportField.account) != null;
    final hasTypeColumn = mapping.columnOf(ImportField.type) != null;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(fileName, style: theme.textTheme.titleSmall),
                Text(
                  tr('{rows} rows, {columns} columns', {
                    'rows': table.rows.length,
                    'columns': table.columnCount,
                  }),
                  key: const ValueKey('file-summary'),
                  style: theme.textTheme.bodySmall,
                ),
                SwitchListTile(
                  key: const ValueKey('has-header'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('The first row has column names')),
                  value: hasHeader,
                  onChanged: onHasHeaderChanged,
                ),
              ],
            ),
          ),
        ),
        if (remembered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tr(
                'The columns are set as they were for your last file like '
                'this. Check them.',
              ),
              key: const ValueKey('remembered-mapping'),
              style: theme.textTheme.bodySmall,
            ),
          ),
        heading(tr('Which column is which?')),
        for (final field in ImportField.values.where(
          (f) => f.isAskedFor(mapping.typeSource),
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<int?>(
              key: ValueKey('field-${field.name}-${mapping.columnOf(field)}'),
              initialValue: mapping.columnOf(field),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: field.isRequired ? '${field.label} *' : field.label,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    field.isRequired
                        ? tr('Choose a column')
                        : tr('Not in my file'),
                  ),
                ),
                for (var i = 0; i < table.columnCount; i++)
                  DropdownMenuItem<int?>(
                    value: i,
                    child: Text(
                      _sample(i).isEmpty
                          ? table.headers[i]
                          : '${table.headers[i]}  ·  ${_sample(i)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (column) => onFieldChanged(field, column),
            ),
          ),
        heading(tr('Dates')),
        DropdownButtonFormField<SheetDateFormat>(
          key: ValueKey('date-format-${mapping.dateFormat.name}'),
          initialValue: mapping.dateFormat,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('Dates are written as'),
            helperText: _dateExample(),
          ),
          items: [
            for (final format in SheetDateFormat.values)
              DropdownMenuItem(
                value: format,
                child: Text('${format.label}  (${format.example})'),
              ),
          ],
          onChanged: (format) {
            if (format != null) onDateFormatChanged(format);
          },
        ),
        heading(tr('Income and expense')),
        DropdownButtonFormField<TypeSource>(
          key: ValueKey(
            'type-source-${mapping.typeSource.name}-$hasTypeColumn',
          ),
          initialValue: mapping.typeSource,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('Income or expense comes from'),
          ),
          items: [
            for (final source in TypeSource.values)
              DropdownMenuItem(
                value: source,
                enabled: source != TypeSource.column || hasTypeColumn,
                child: Text(source.label),
              ),
          ],
          onChanged: (source) {
            if (source != null) onTypeSourceChanged(source);
          },
        ),
        heading(tr('Account')),
        DropdownButtonFormField<int?>(
          key: ValueKey(
            'default-account-${mapping.defaultAccountId}-$hasAccountColumn',
          ),
          initialValue: mapping.defaultAccountId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: hasAccountColumn
                ? tr('Account for rows that have none')
                : tr('Account for these transactions'),
            helperText: accounts.isEmpty
                ? tr(
                    'You have no accounts yet. Choose an Account column above '
                    'and the accounts in your file will be created.',
                  )
                : null,
            helperMaxLines: 3,
          ),
          items: [
            DropdownMenuItem<int?>(value: null, child: Text(tr('None'))),
            for (final account in accounts)
              DropdownMenuItem<int?>(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: onDefaultAccountChanged,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('create-account'),
            onPressed: onCreateAccount,
            icon: const Icon(Icons.add),
            label: Text(tr('New account')),
          ),
        ),
      ],
    );
  }
}

enum _RowFilter { all, toImport, duplicates, errors, check }

/// The third step: what the import will do.
class ImportPreviewStep extends StatefulWidget {
  const ImportPreviewStep({
    required this.plan,
    this.matches = const [],
    this.onChooseCategory,
    this.onUseSuggestion,
    this.onClearMatch,
    super.key,
  });

  final ImportPlan plan;

  /// The categories matched with the app's by hand, so that they can be taken
  /// back.
  final List<MatchedCategory> matches;

  /// Asks which category of the app a new category should be.
  final ValueChanged<CategoryToCreate>? onChooseCategory;

  /// Matches a new category with the one that looks like it.
  final ValueChanged<CategoryToCreate>? onUseSuggestion;

  /// Takes a match back, by its key.
  final ValueChanged<String>? onClearMatch;

  /// The most rows listed, so the screen stays fast for a big file.
  static const maxRowsShown = 200;

  @override
  State<ImportPreviewStep> createState() => _ImportPreviewStepState();
}

class _ImportPreviewStepState extends State<ImportPreviewStep> {
  _RowFilter _filter = _RowFilter.all;

  List<PlannedRow> get _rows => switch (_filter) {
    _RowFilter.all => widget.plan.rows,
    _RowFilter.toImport =>
      widget.plan.rows.where((r) => r.status == RowStatus.ok).toList(),
    _RowFilter.duplicates =>
      widget.plan.rows.where((r) => r.status == RowStatus.duplicate).toList(),
    _RowFilter.errors =>
      widget.plan.rows.where((r) => r.status == RowStatus.error).toList(),
    _RowFilter.check =>
      widget.plan.rows.where((r) => r.warning != null).toList(),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final plan = widget.plan;
    final rows = _rows;
    final shown = rows.take(ImportPreviewStep.maxRowsShown).toList();

    Widget count(String key, int value, String label, Color? color) => Expanded(
      child: Column(
        children: [
          Text(
            localizeDigits('$value'),
            key: ValueKey(key),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                count(
                  'count-import',
                  plan.importCount,
                  tr('will be\nimported'),
                  colors.income,
                ),
                count(
                  'count-duplicates',
                  plan.duplicateCount,
                  tr('already in\nthe app'),
                  null,
                ),
                count(
                  'count-errors',
                  plan.errorCount,
                  tr('cannot be\nread'),
                  plan.errorCount > 0 ? colors.expense : null,
                ),
              ],
            ),
          ),
        ),
        if (plan.warningCount > 0)
          Card(
            key: const ValueKey('odd-dates'),
            margin: const EdgeInsets.only(top: 8),
            child: ListTile(
              leading: Icon(
                Icons.warning_amber_rounded,
                color: theme.colorScheme.tertiary,
              ),
              title: Text(
                tr('{rows} to check', {
                  'rows': plural(plan.warningCount, '1 row', '{n} rows'),
                }),
              ),
              subtitle: Text(
                tr(
                  'Their dates do not fit the rows around them. They will be '
                  'imported as they are.',
                ),
              ),
              onTap: () => setState(() => _filter = _RowFilter.check),
            ),
          ),
        if (plan.accountChanges.isNotEmpty)
          Card(
            key: const ValueKey('balance-changes'),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('What changes in your accounts'),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  for (final change in plan.accountChanges)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(change.name),
                                if (change.isNew || !change.includeInTotal)
                                  Text(
                                    [
                                      if (change.isNew) tr('new account'),
                                      if (!change.includeInTotal)
                                        tr('not in your total balance'),
                                    ].join(' · '),
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            '${change.change > 0 ? '+' : ''}'
                            '${formatPoisha(change.change)}',
                            key: ValueKey('balance-change-${change.name}'),
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: change.change < 0
                                  ? colors.expense
                                  : colors.income,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (plan.newAccounts.isNotEmpty || plan.newCategories.isNotEmpty)
          Card(
            key: const ValueKey('will-create'),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Will also be created'),
                    style: theme.textTheme.titleSmall,
                  ),
                  if (plan.newAccounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      tr('Accounts: {names}', {
                        'names': plan.newAccounts.join(', '),
                      }),
                    ),
                  ],
                  if (plan.newCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(tr('Categories:')),
                    for (final category in plan.newCategories)
                      _NewCategoryRow(
                        category: category,
                        onChoose: widget.onChooseCategory,
                        onUseSuggestion: widget.onUseSuggestion,
                      ),
                  ],
                ],
              ),
            ),
          ),
        if (widget.matches.isNotEmpty)
          Card(
            key: const ValueKey('matched-categories'),
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Matched with your categories'),
                    style: theme.textTheme.titleSmall,
                  ),
                  for (final match in widget.matches)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${match.fileLabel}  →  ${match.appLabel}',
                          ),
                        ),
                        IconButton(
                          key: ValueKey('unmatch-${match.key}'),
                          tooltip: tr('Take back'),
                          icon: const Icon(Icons.close),
                          onPressed: () => widget.onClearMatch?.call(match.key),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (filter, label) in [
              (_RowFilter.all, tr('All')),
              (_RowFilter.toImport, tr('To import')),
              (_RowFilter.duplicates, tr('Already in the app')),
              (_RowFilter.errors, tr('Cannot be read')),
              if (plan.warningCount > 0) (_RowFilter.check, tr('To check')),
            ])
              ChoiceChip(
                label: Text(label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                tr('No rows here.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        for (final row in shown) _PlannedRowTile(row: row),
        if (rows.length > shown.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr('Showing the first {shown} of {total} rows.', {
                'shown': shown.length,
                'total': rows.length,
              }),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

/// A category the import will make, with a way to use one of the app's instead.
class _NewCategoryRow extends StatelessWidget {
  const _NewCategoryRow({
    required this.category,
    required this.onChoose,
    required this.onUseSuggestion,
  });

  final CategoryToCreate category;
  final ValueChanged<CategoryToCreate>? onChoose;
  final ValueChanged<CategoryToCreate>? onUseSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestion = category.suggestion;
    return Row(
      key: ValueKey('new-category-${category.key}'),
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ${category.label}'),
              if (suggestion != null)
                Text(
                  tr('Looks like "{name}", which you have.', {
                    'name': suggestion.name,
                  }),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (suggestion != null)
          TextButton(
            key: ValueKey('use-suggestion-${category.key}'),
            onPressed: () => onUseSuggestion?.call(category),
            child: Text(tr('Use it')),
          ),
        IconButton(
          key: ValueKey('choose-category-${category.key}'),
          tooltip: tr('Use a category I have'),
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => onChoose?.call(category),
        ),
      ],
    );
  }
}

class _PlannedRowTile extends StatelessWidget {
  const _PlannedRowTile({required this.row});

  final PlannedRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final parsed = row.parsed;

    final (icon, color) = switch (row.status) {
      RowStatus.ok when row.warning != null => (
        Icons.warning_amber_rounded,
        theme.colorScheme.tertiary,
      ),
      RowStatus.ok => (Icons.check_circle_outline, colors.income),
      RowStatus.duplicate => (
        Icons.content_copy_outlined,
        theme.colorScheme.outline,
      ),
      RowStatus.error => (Icons.error_outline, colors.expense),
    };

    final String title;
    final String subtitle;
    if (parsed == null) {
      title = tr('Row {number}', {'number': row.rowNumber});
      subtitle = row.error ?? '';
    } else {
      final typeLabel = switch (parsed.type) {
        TransactionType.income => tr('Income'),
        TransactionType.expense => tr('Expense'),
        TransactionType.transfer => tr('Transfer'),
      };
      title = '$typeLabel ${formatPoisha(parsed.amount)}';
      final where = parsed.type == TransactionType.transfer
          ? '${parsed.accountName} → ${parsed.toAccountName}'
          : '${parsed.accountName} · ${parsed.categoryPath.join(' > ')}';
      subtitle = [
        DateFormat('d MMM yyyy').format(parsed.date),
        where,
        if (parsed.note.isNotEmpty) parsed.note,
        if (row.status == RowStatus.duplicate)
          tr('Already in the app, skipped'),
        if (row.warning != null) row.warning!,
      ].join(' · ');
    }

    return ListTile(
      key: ValueKey('plan-row-${row.rowNumber}'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    );
  }
}

/// The last step: what was done.
class ImportDoneStep extends StatelessWidget {
  const ImportDoneStep({required this.result, this.onUndo, super.key});

  final ImportResult result;

  /// Takes the import back. Null hides the button.
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget line(String text) => Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, textAlign: TextAlign.center),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 64,
          color: context.financeColors.income,
        ),
        const SizedBox(height: 16),
        Text(
          tr('Imported {transactions}', {
            'transactions': plural(
              result.imported,
              '1 transaction',
              '{n} transactions',
            ),
          }),
          key: const ValueKey('import-result'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (result.accountsCreated > 0)
          line(
            tr('Created {accounts}', {
              'accounts': plural(
                result.accountsCreated,
                '1 account',
                '{n} accounts',
              ),
            }),
          ),
        if (result.categoriesCreated > 0)
          line(
            tr('Created {categories}', {
              'categories': plural(
                result.categoriesCreated,
                '1 category',
                '{n} categories',
              ),
            }),
          ),
        if (result.duplicates > 0)
          line(
            tr('{rows} skipped, already in the app', {
              'rows': plural(result.duplicates, '1 row', '{n} rows'),
            }),
          ),
        if (result.errors > 0)
          line(
            tr('{rows} skipped, could not be read', {
              'rows': plural(result.errors, '1 row', '{n} rows'),
            }),
          ),
        if (onUndo != null && result.batchId != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              key: const ValueKey('undo-import'),
              onPressed: onUndo,
              icon: const Icon(Icons.undo),
              label: Text(tr('Undo this import')),
            ),
          ),
        ],
      ],
    );
  }
}
