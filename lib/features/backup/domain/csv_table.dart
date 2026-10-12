import 'package:csv/csv.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/validation_exception.dart';

/// The rows of a CSV file, ready to be mapped to transaction fields.
class CsvTable {
  const CsvTable({required this.headers, required this.rows});

  /// One name per column: the first row of the file, or `Column 1`,
  /// `Column 2`, ... when the file has no header row.
  final List<String> headers;

  /// The data rows. Every row has one cell per header, trimmed.
  final List<List<String>> rows;

  int get columnCount => headers.length;

  /// The cell at [row] (0 based) and [column], or an empty string.
  String cell(int row, int column) =>
      column < 0 || column >= columnCount ? '' : rows[row][column];
}

/// Reads CSV text. The separator (comma, semicolon or tab) is found by
/// itself, quoted cells may hold separators and line breaks, a leading byte
/// order mark and empty lines are ignored. Set [hasHeader] to false when the
/// first row is data.
///
/// Throws a [ValidationException] when the text has no rows.
CsvTable parseCsvTable(String text, {bool hasHeader = true}) {
  final input = text.startsWith('﻿') ? text.substring(1) : text;

  final List<List<String>> rows;
  try {
    rows = [
      for (final row in csv.decode(input))
        [for (final cell in row) '$cell'.trim()],
    ].where((row) => row.any((cell) => cell.isNotEmpty)).toList();
  } on Object {
    throw ValidationException(tr('This file is not a readable CSV.'));
  }
  if (rows.isEmpty) {
    throw ValidationException(tr('The file has no rows.'));
  }

  final width = rows.fold(
    0,
    (widest, row) => row.length > widest ? row.length : widest,
  );
  List<String> padded(List<String> row) => [
    ...row,
    for (var i = row.length; i < width; i++) '',
  ];

  final headers = hasHeader
      ? padded(rows.first)
      : [for (var i = 1; i <= width; i++) 'Column $i'];
  final dataRows = (hasHeader ? rows.skip(1) : rows).map(padded).toList();
  return CsvTable(headers: headers, rows: dataRows);
}
