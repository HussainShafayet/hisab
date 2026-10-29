import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/csv_table.dart';
import 'package:hishab/features/bazar/domain/shopping.dart';

/// One answer of the form: a row of its sheet. It can hold several things to
/// buy, one on each line or between commas.
class FormRow {
  const FormRow({required this.names, this.quantity = 1});

  /// The things in the answer, none of them blank.
  final List<String> names;

  /// How many, when the sheet has a column for it.
  final int quantity;
}

/// One thing to put on the list.
class FormItem {
  const FormItem({required this.name, this.quantity = 1});

  final String name;
  final int quantity;
}

/// The address to read a published Google Sheet as CSV from, out of what the
/// person pasted. Accepts the link of File > Share > Publish to web (`.../pub`,
/// made CSV) and a sheet that anyone with the link can view (`.../edit`, made an
/// export). Throws a [ValidationException] for anything else.
Uri sheetCsvUri(String input) {
  final uri = Uri.tryParse(input.trim());
  final ok =
      uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'docs.google.com' &&
      uri.path.startsWith('/spreadsheets/');
  if (!ok) {
    throw ValidationException(
      tr(
        'Paste the link from File > Share > Publish to web in the sheet of '
        'your form (choose CSV).',
      ),
    );
  }
  final params = Map<String, String>.of(uri.queryParameters);
  if (uri.path.endsWith('/pub')) {
    params['output'] = 'csv';
    return uri.replace(queryParameters: params);
  }
  final id = RegExp(r'/spreadsheets/d/([^/]+)').firstMatch(uri.path)?.group(1);
  if (id == null || id == 'e') {
    throw ValidationException(
      tr(
        'Paste the link from File > Share > Publish to web in the sheet of '
        'your form (choose CSV).',
      ),
    );
  }
  final gid = RegExp(r'gid=(\d+)').firstMatch(uri.fragment)?.group(1);
  return Uri.https('docs.google.com', '/spreadsheets/d/$id/export', {
    'format': 'csv',
    'gid': ?gid ?? params['gid'],
  });
}

/// The answers in the CSV of a form's responses sheet. The column of the items
/// is the first one whose title has "item" in it, else the second (the first is
/// the time), and a column called quantity, qty or "how many" says how many.
/// Every row is kept, even one with nothing in it, because rows are counted. An
/// answer with several things is split (see [splitItems]).
List<FormRow> readFormRows(String csvText) {
  final table = parseCsvTable(csvText);
  final headers = [for (final h in table.headers) h.toLowerCase()];
  var itemColumn = headers.indexWhere(
    (h) => h.contains('item') || h.contains('jinis') || h.contains('name'),
  );
  if (itemColumn < 0) itemColumn = table.columnCount > 1 ? 1 : 0;
  final quantityColumn = headers.indexWhere(
    (h) =>
        h.contains('quantity') || h.contains('qty') || h.contains('how many'),
  );

  final rows = <FormRow>[];
  for (var i = 0; i < table.rows.length; i++) {
    final names = splitItems(table.cell(i, itemColumn));
    // A quantity belongs to one thing, so it is only read for an answer that
    // holds one.
    final quantity = quantityColumn < 0 || names.length != 1
        ? 1
        : (int.tryParse(table.cell(i, quantityColumn)) ?? 1).clamp(1, 9999);
    rows.add(FormRow(names: names, quantity: quantity));
  }
  return rows;
}

/// The things in one answer: split at line breaks, commas and semicolons, a
/// list mark (`-`, `*`, a bullet, `1.`, `1)`) taken off the front of each, and
/// the blank ones left out.
List<String> splitItems(String answer) {
  final marker = RegExp(r'^(?:[-*•·‣▪–—]+|[0-9০-৯]+[.)])\s*');
  return [
    for (final part in answer.split(RegExp(r'[\r\n,;،]+')))
      if (cleanItemName(part.trim().replaceFirst(marker, '')).isNotEmpty)
        cleanItemName(part.trim().replaceFirst(marker, '')),
  ];
}

/// A name for the list: blanks squeezed, cut to the longest name.
String cleanItemName(String text) {
  final squeezed = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  return squeezed.length > maxItemNameLength
      ? squeezed.substring(0, maxItemNameLength).trim()
      : squeezed;
}

/// What an import takes from the answers.
class FormImportPlan {
  const FormImportPlan({required this.toAdd, required this.imported});

  /// The new items, in the order they were answered.
  final List<FormItem> toAdd;

  /// How many rows have been taken once this import is done.
  final int imported;
}

/// The answers only ever get longer, so what was taken before is told by
/// *how many* rows, not by which: the ones after [imported] are new. A sheet
/// with fewer rows than that was cleaned, and what is in it now was seen: it
/// takes nothing, and counts from there. Rows without an item are counted but
/// add nothing, and a row with several things adds each.
FormImportPlan planFormImport({
  required List<FormRow> rows,
  required int imported,
}) {
  if (rows.length < imported) {
    return FormImportPlan(toAdd: const [], imported: rows.length);
  }
  return FormImportPlan(
    toAdd: [
      for (final row in rows.skip(imported))
        for (final name in row.names)
          FormItem(name: name, quantity: row.quantity),
    ],
    imported: rows.length,
  );
}
