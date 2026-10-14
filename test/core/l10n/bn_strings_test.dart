import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/fun/domain/quips.dart';
import 'package:hishab/core/l10n/bn_strings.dart';
import 'package:hishab/features/backup/domain/import_mapping.dart';
import 'package:hishab/features/backup/domain/sheet_date.dart';

final _placeholder = RegExp(r'\{\w+\}');

/// The texts passed to `tr(...)` and `plural(...)` in a source file. Reads
/// the string literals that follow the opening bracket, joined when they are
/// written one after another, and ignores calls whose text is not a literal.
List<String> translationKeysIn(String source) {
  final keys = <String>[];
  for (final call in RegExp(r'(?<![\w.])(tr|plural)\(').allMatches(source)) {
    var i = call.end;
    if (call.group(1) == 'plural') {
      // plural(count, 'one', 'other'): skip the count.
      var depth = 0;
      while (i < source.length) {
        final c = source[i];
        if (c == '(' || c == '[' || c == '{') depth++;
        if (c == ')' || c == ']' || c == '}') {
          if (depth == 0) break;
          depth--;
        }
        if (c == ',' && depth == 0) break;
        i++;
      }
      i++;
      for (var form = 0; form < 2; form++) {
        final literal = _readLiteral(source, i);
        if (literal == null) break;
        keys.add(literal.text);
        i = literal.end;
        while (i < source.length && ' \n\t,'.contains(source[i])) {
          i++;
        }
      }
      continue;
    }
    final literal = _readLiteral(source, i);
    if (literal != null) keys.add(literal.text);
  }
  return keys;
}

({String text, int end})? _readLiteral(String source, int from) {
  var i = from;
  while (i < source.length && ' \n\t'.contains(source[i])) {
    i++;
  }
  final buffer = StringBuffer();
  var found = false;
  while (i < source.length && (source[i] == "'" || source[i] == '"')) {
    final quote = source[i];
    i++;
    while (i < source.length && source[i] != quote) {
      if (source[i] == r'\') {
        final next = source[i + 1];
        buffer.write(switch (next) {
          'n' => '\n',
          't' => '\t',
          _ => next,
        });
        i += 2;
      } else {
        buffer.write(source[i]);
        i++;
      }
    }
    i++;
    found = true;
    // Another literal right after this one is part of the same text.
    var j = i;
    while (j < source.length && ' \n\t'.contains(source[j])) {
      j++;
    }
    if (j < source.length && (source[j] == "'" || source[j] == '"')) i = j;
  }
  return found ? (text: buffer.toString(), end: i) : null;
}

void main() {
  group('the dictionary', () {
    test('has a Bangla text for every entry', () {
      for (final entry in bnStrings.entries) {
        expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('keeps the placeholders of the English text', () {
      for (final entry in bnStrings.entries) {
        final english =
            _placeholder.allMatches(entry.key).map((m) => m[0]).toList()
              ..sort();
        final bangla =
            _placeholder.allMatches(entry.value).map((m) => m[0]).toList()
              ..sort();
        expect(bangla, english, reason: entry.key);
      }
    });

    test('keeps the line breaks of the English text', () {
      for (final entry in bnStrings.entries) {
        expect(
          '\n'.allMatches(entry.value).length,
          '\n'.allMatches(entry.key).length,
          reason: entry.key,
        );
      }
    });

    test('does not translate a text into itself', () {
      for (final entry in bnStrings.entries) {
        expect(entry.value, isNot(entry.key));
      }
    });
  });

  group('every text the app passes to tr()', () {
    test('has a Bangla entry', () {
      final missing = <String>{};
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('.g.dart') ||
            file.path.endsWith('bn_strings.dart') ||
            file.path.endsWith('translator.dart')) {
          continue;
        }
        for (final key in translationKeysIn(file.readAsStringSync())) {
          if (!bnStrings.containsKey(key)) missing.add('${file.path}: $key');
        }
      }

      expect(missing, isEmpty, reason: 'texts with no Bangla entry');
    });

    test('is found by the scanner (the scan itself works)', () {
      expect(
        translationKeysIn(
          "Text(tr('Hello')); tr('a ' 'b'); plural(n, '1 x', '{n} xs');",
        ),
        ['Hello', 'a b', '1 x', '{n} xs'],
      );
    });
  });

  group('labels written as enum constants', () {
    test('have a Bangla entry', () {
      final english = [
        for (final field in ImportField.values) field.label,
        for (final source in TypeSource.values) source.label,
        for (final format in SheetDateFormat.values) format.label,
        'account',
        'category',
        'transaction',
        'loan',
        'recurring item',
        // Takka's lines are chosen at run time, then passed to tr().
        ...allQuips,
      ];

      for (final text in english) {
        expect(bnStrings.containsKey(text), isTrue, reason: text);
      }
    });
  });

  group('no entry that nothing uses', () {
    test('every entry is used somewhere', () {
      final used = <String>{
        for (final field in ImportField.values) field.label,
        for (final source in TypeSource.values) source.label,
        for (final format in SheetDateFormat.values) format.label,
        'account',
        'category',
        'transaction',
        'loan',
        'recurring item',
        ...allQuips,
      };
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        if (file.path.endsWith('.g.dart') ||
            file.path.endsWith('bn_strings.dart')) {
          continue;
        }
        used.addAll(translationKeysIn(file.readAsStringSync()));
      }

      final unused = bnStrings.keys
          .where((key) => !used.contains(key))
          .toList();

      expect(unused, isEmpty, reason: 'entries no tr() call asks for');
    });
  });
}
