import 'package:flutter/material.dart';
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
          'Import transactions from a CSV file',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'In Google Sheets or Excel, save your sheet as CSV (in Sheets: File, '
          'Download, Comma-separated values). Then choose that file here. '
          'You will say which column is which, and see a preview before '
          'anything is added.',
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
    if (text == null) return 'The date column is empty.';
    final date = parseSheetDate(text, mapping.dateFormat);
    return date == null
        ? '"$text" cannot be read in this order.'
        : '"$text" is ${DateFormat('d MMMM yyyy').format(date)}.';
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
                  '${table.rows.length} rows, ${table.columnCount} columns',
                  key: const ValueKey('file-summary'),
                  style: theme.textTheme.bodySmall,
                ),
                SwitchListTile(
                  key: const ValueKey('has-header'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('The first row has column names'),
                  value: hasHeader,
                  onChanged: onHasHeaderChanged,
                ),
              ],
            ),
          ),
        ),
        heading('Which column is which?'),
        for (final field in ImportField.values)
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
                    field.isRequired ? 'Choose a column' : 'Not in my file',
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
        heading('Dates'),
        DropdownButtonFormField<SheetDateFormat>(
          key: ValueKey('date-format-${mapping.dateFormat.name}'),
          initialValue: mapping.dateFormat,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Dates are written as',
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
        heading('Income and expense'),
        DropdownButtonFormField<TypeSource>(
          key: ValueKey(
            'type-source-${mapping.typeSource.name}-$hasTypeColumn',
          ),
          initialValue: mapping.typeSource,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Income or expense comes from',
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
        heading('Account'),
        DropdownButtonFormField<int?>(
          key: ValueKey(
            'default-account-${mapping.defaultAccountId}-$hasAccountColumn',
          ),
          initialValue: mapping.defaultAccountId,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: hasAccountColumn
                ? 'Account for rows that have none'
                : 'Account for these transactions',
            helperText: accounts.isEmpty
                ? 'You have no accounts yet. Choose an Account column above and '
                      'the accounts in your file will be created.'
                : null,
            helperMaxLines: 3,
          ),
          items: [
            const DropdownMenuItem<int?>(value: null, child: Text('None')),
            for (final account in accounts)
              DropdownMenuItem<int?>(
                value: account.id,
                child: Text(account.name),
              ),
          ],
          onChanged: onDefaultAccountChanged,
        ),
      ],
    );
  }
}

enum _RowFilter { all, toImport, duplicates, errors }

/// The third step: what the import will do.
class ImportPreviewStep extends StatefulWidget {
  const ImportPreviewStep({required this.plan, super.key});

  final ImportPlan plan;

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
            '$value',
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
                  'will be\nimported',
                  colors.income,
                ),
                count(
                  'count-duplicates',
                  plan.duplicateCount,
                  'already in\nthe app',
                  null,
                ),
                count(
                  'count-errors',
                  plan.errorCount,
                  'cannot be\nread',
                  plan.errorCount > 0 ? colors.expense : null,
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
                    'Will also be created',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (plan.newAccounts.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Accounts: ${plan.newAccounts.join(', ')}'),
                  ],
                  if (plan.newCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Categories: ${[for (final c in plan.newCategories) c.label].join(', ')}',
                    ),
                  ],
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (filter, label) in [
              (_RowFilter.all, 'All'),
              (_RowFilter.toImport, 'To import'),
              (_RowFilter.duplicates, 'Already in the app'),
              (_RowFilter.errors, 'Cannot be read'),
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
              child: Text('No rows here.', style: theme.textTheme.bodyMedium),
            ),
          ),
        for (final row in shown) _PlannedRowTile(row: row),
        if (rows.length > shown.length)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Showing the first ${shown.length} of ${rows.length} rows.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
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
      title = 'Row ${row.rowNumber}';
      subtitle = row.error ?? '';
    } else {
      final typeLabel = switch (parsed.type) {
        TransactionType.income => 'Income',
        TransactionType.expense => 'Expense',
        TransactionType.transfer => 'Transfer',
      };
      title = '$typeLabel ${formatPoisha(parsed.amount)}';
      final where = parsed.type == TransactionType.transfer
          ? '${parsed.accountName} → ${parsed.toAccountName}'
          : '${parsed.accountName} · ${parsed.categoryPath.join(' > ')}';
      subtitle = [
        DateFormat('d MMM yyyy').format(parsed.date),
        where,
        if (parsed.note.isNotEmpty) parsed.note,
        if (row.status == RowStatus.duplicate) 'Already in the app, skipped',
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
  const ImportDoneStep({required this.result, super.key});

  final ImportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String count(int n, String noun) => '$n $noun${n == 1 ? '' : 's'}';

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
          'Imported ${count(result.imported, 'transaction')}',
          key: const ValueKey('import-result'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (result.accountsCreated > 0)
          line('Created ${count(result.accountsCreated, 'account')}'),
        if (result.categoriesCreated > 0)
          line(
            'Created ${result.categoriesCreated} ${result.categoriesCreated == 1 ? 'category' : 'categories'}',
          ),
        if (result.duplicates > 0)
          line(
            '${count(result.duplicates, 'row')} skipped, already in the app',
          ),
        if (result.errors > 0)
          line('${count(result.errors, 'row')} skipped, could not be read'),
      ],
    );
  }
}
