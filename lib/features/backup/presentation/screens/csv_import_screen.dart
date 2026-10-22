import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/files/file_gateway.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/backup/data/csv_import_repository.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/import_plan.dart';
import 'package:hishab/features/backup/presentation/providers/backup_providers.dart';
import 'package:hishab/features/backup/presentation/widgets/csv_import_steps.dart';
import 'package:hishab/features/backup/presentation/widgets/undo_import.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/categories/presentation/widgets/category_picker_sheet.dart';

enum _Step { choose, map, preview, done }

/// Imports transactions from a CSV file in four steps: choose the file, say
/// which column is which, look at a preview, and import.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  _Step _step = _Step.choose;
  bool _busy = false;
  String? _error;

  String _fileName = '';
  String _text = '';
  bool _hasHeader = true;
  CsvTable? _table;
  ImportMapping? _mapping;
  ImportContext? _context;
  List<Account> _accounts = const [];
  ImportPlan? _plan;
  ImportResult? _result;

  /// The columns were taken from the last file with the same column names.
  bool _remembered = false;

  /// The categories of the file that the person matched with one of the app's,
  /// by the key the plan uses.
  final Map<String, ({int id, MatchedCategory match})> _matched = {};

  String get _title => switch (_step) {
    _Step.choose => tr('Import from CSV'),
    _Step.map => tr('Match your columns'),
    _Step.preview => tr('Preview'),
    _Step.done => tr('Import finished'),
  };

  Future<void> _chooseFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final picked = await ref
          .read(fileGatewayProvider)
          .pick(extensions: ['csv', 'txt']);
      if (picked == null) return;
      try {
        _text = utf8.decode(picked.bytes);
      } on FormatException {
        _error = tr(
          'This file is not UTF-8 text. In Excel or Sheets, save it as '
          '"CSV UTF-8" and try again.',
        );
        return;
      }
      _fileName = picked.name;
      _hasHeader = true;
      await _load();
    } on Object catch (error) {
      _error = describeError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Reads [_text] with the current header setting and starts a mapping.
  Future<void> _load() async {
    final CsvTable table;
    try {
      table = parseCsvTable(_text, hasHeader: _hasHeader);
    } on Object catch (e) {
      _error = describeError(e);
      _step = _Step.choose;
      return;
    }
    if (table.rows.isEmpty) {
      _error = tr('The file has column names but no rows.');
      _step = _Step.choose;
      return;
    }

    final context = await ref.read(csvImportRepositoryProvider).loadContext();
    final accounts = await ref.read(accountsRepositoryProvider).getAccounts();
    final suggested = suggestMapping(
      table,
      hasHeader: _hasHeader,
      defaultAccountId: accounts.firstOrNull?.id,
    );
    // A file with the same column names as an earlier one is set up the same.
    final saved = _hasHeader
        ? await ref
              .read(csvImportRepositoryProvider)
              .savedMapping(table.headers, columnCount: table.columnCount)
        : null;
    _table = table;
    _context = context;
    _accounts = accounts;
    _remembered = saved != null;
    _mapping = saved == null
        ? suggested
        : saved.copyWith(
            defaultAccountId: () =>
                accounts.any((a) => a.id == saved.defaultAccountId)
                ? saved.defaultAccountId
                : suggested.defaultAccountId,
          );
    _matched.clear();
    _error = null;
    _step = _Step.map;
  }

  Future<void> _setHasHeader(bool value) async {
    setState(() => _busy = true);
    _hasHeader = value;
    try {
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _setField(ImportField field, int? column) {
    final mapping = _mapping!;
    final columns = {...mapping.columns};
    if (column == null) {
      columns.remove(field);
    } else {
      columns[field] = column;
    }

    var typeSource = mapping.typeSource;
    if (field == ImportField.type) {
      if (column != null) {
        typeSource = TypeSource.column;
      } else if (typeSource == TypeSource.column) {
        typeSource = TypeSource.allExpense;
      }
    }
    setState(
      () =>
          _mapping = mapping.copyWith(columns: columns, typeSource: typeSource),
    );
  }

  ImportPlan _buildPlan() => buildImportPlan(
    table: _table!,
    mapping: _mapping!,
    context: _context!,
    categoryMap: {for (final e in _matched.entries) e.key: e.value.id},
  );

  /// Where the type of a row comes from. With a column for income and one
  /// for expense, the two columns are looked for by their names.
  void _setTypeSource(TypeSource source) {
    final mapping = _mapping!;
    var columns = mapping.columns;
    if (source == TypeSource.twoColumns && _hasHeader) {
      final guess = guessColumns(_table!.headers);
      columns = {
        ...columns,
        for (final field in [
          ImportField.incomeAmount,
          ImportField.expenseAmount,
        ])
          if (columns[field] == null && guess[field] != null)
            field: guess[field]!,
      };
    }
    setState(
      () => _mapping = mapping.copyWith(typeSource: source, columns: columns),
    );
  }

  void _showPreview() {
    setState(() {
      _matched.clear();
      _plan = _buildPlan();
      _step = _Step.preview;
    });
  }

  /// Makes an account for the rows to go in, and chooses it.
  Future<void> _createAccount() async {
    final input = await showNewAccountDialog(context);
    if (input == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final accounts = ref.read(accountsRepositoryProvider);
      final id = await accounts.createAccount(
        name: input.name,
        type: guessAccountType(input.name),
        includeInTotal: input.includeInTotal,
      );
      final all = await accounts.getAccounts();
      final context = await ref.read(csvImportRepositoryProvider).loadContext();
      if (!mounted) return;
      setState(() {
        _accounts = all;
        _context = context;
        _mapping = _mapping!.copyWith(defaultAccountId: () => id);
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showError(describeError(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Matches the new category [category] with the app's category [id].
  void _match(CategoryToCreate category, int id, Map<int, Category> byId) {
    final target = byId[id];
    if (target == null) return;
    setState(() {
      _matched[category.key] = (
        id: id,
        match: MatchedCategory(
          key: category.key,
          fileLabel: category.label,
          appLabel: categoryPathLabel(target, byId),
        ),
      );
      _plan = _buildPlan();
    });
  }

  Future<Map<int, Category>> _categoriesById() async => {
    for (final c
        in await ref.read(categoriesRepositoryProvider).getCategories())
      c.id: c,
  };

  Future<void> _useSuggestion(CategoryToCreate category) async {
    final suggestion = category.suggestion;
    if (suggestion == null) return;
    _match(category, suggestion.id, await _categoriesById());
  }

  Future<void> _chooseCategory(CategoryToCreate category) async {
    final byId = await _categoriesById();
    if (!mounted) return;
    final ofType = byId.values.where((c) => c.type == category.type);
    final pick = await showCategoryPicker(
      context,
      title: tr('Which of your categories is "{name}"?', {
        'name': category.label,
      }),
      categories: flattenCategoryTree(buildCategoryTree(ofType)),
      allowAdd: false,
    );
    if (pick is CategoryPicked) _match(category, pick.id, byId);
  }

  void _clearMatch(String key) {
    setState(() {
      _matched.remove(key);
      _plan = _buildPlan();
    });
  }

  Future<void> _undo() async {
    final batchId = _result?.batchId;
    if (batchId == null) return;
    final undone = await undoImportAfterAsking(context, ref, batchId);
    if (undone && mounted) context.pop();
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final repository = ref.read(csvImportRepositoryProvider);
      final result = await repository.apply(_plan!, fileName: _fileName);
      if (_hasHeader) {
        // The next file with these columns starts from this mapping.
        try {
          await repository.saveMapping(_table!.headers, _mapping!);
        } on Object {
          // Not being able to remember the columns must not undo an import.
        }
      }
      if (!mounted) return;
      setState(() {
        _result = result;
        _step = _Step.done;
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showError(
          tr('Nothing was imported. {reason}', {
            'reason': describeError(error),
          }),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    setState(() {
      _step = switch (_step) {
        _Step.preview => _Step.map,
        _Step.map => _Step.choose,
        _ => _step,
      };
    });
  }

  Widget _body() => switch (_step) {
    _Step.choose => ImportChooseStep(error: _error),
    _Step.map => ImportMapStep(
      fileName: _fileName,
      table: _table!,
      hasHeader: _hasHeader,
      mapping: _mapping!,
      accounts: _accounts,
      onHasHeaderChanged: _setHasHeader,
      onFieldChanged: _setField,
      onDateFormatChanged: (format) =>
          setState(() => _mapping = _mapping!.copyWith(dateFormat: format)),
      onTypeSourceChanged: _setTypeSource,
      onCreateAccount: _createAccount,
      remembered: _remembered,
      onDefaultAccountChanged: (id) => setState(
        () => _mapping = _mapping!.copyWith(defaultAccountId: () => id),
      ),
    ),
    _Step.preview => ImportPreviewStep(
      plan: _plan!,
      matches: [for (final m in _matched.values) m.match],
      onChooseCategory: _chooseCategory,
      onUseSuggestion: _useSuggestion,
      onClearMatch: _clearMatch,
    ),
    _Step.done => ImportDoneStep(result: _result!, onUndo: _undo),
  };

  Widget? _bottomBar(BuildContext context) {
    final theme = Theme.of(context);
    Widget bar(List<Widget> children) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(children: children),
      ),
    );

    switch (_step) {
      case _Step.choose:
        return bar([
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : _chooseFile,
              icon: const Icon(Icons.folder_open),
              label: Text(tr('Choose CSV file')),
            ),
          ),
        ]);
      case _Step.map:
        final problem = mappingProblem(_mapping!);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (problem != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      problem,
                      key: const ValueKey('mapping-problem'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: problem == null && !_busy
                            ? _showPreview
                            : null,
                        child: Text(tr('Preview')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      case _Step.preview:
        final count = _plan!.importCount;
        return bar([
          Expanded(
            child: OutlinedButton(
              onPressed: _busy ? null : _back,
              child: Text(tr('Back')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: count == 0 || _busy ? null : _import,
              child: Text(
                count == 1
                    ? tr('Import 1 transaction')
                    : tr('Import {count} transactions', {'count': count}),
              ),
            ),
          ),
        ]);
      case _Step.done:
        return bar([
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.transactions),
              child: Text(tr('See transactions')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () => context.pop(),
              child: Text(tr('Done')),
            ),
          ),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Back goes to the step before, until the first step or the end.
    final canLeave = _step == _Step.choose || _step == _Step.done;

    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title),
          leading: BackButton(
            onPressed: () =>
                canLeave ? context.pop() : (_busy ? null : _back()),
          ),
        ),
        body: Stack(
          children: [_body(), if (_busy) const LinearProgressIndicator()],
        ),
        bottomNavigationBar: _bottomBar(context),
      ),
    );
  }
}
