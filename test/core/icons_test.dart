import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/categories/presentation/category_style.dart';
import 'package:hishab/features/goals/domain/goal.dart';

void main() {
  group('icons', () {
    test('the app never uses the piggy bank icon', () {
      final uses = <String>[];
      for (final file in Directory('lib').listSync(recursive: true)) {
        if (file is! File || !file.path.endsWith('.dart')) continue;
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('Icons.savings')) {
            uses.add('${file.path}:${i + 1}');
          }
        }
      }

      expect(uses, isEmpty, reason: 'Icons.savings is a piggy bank');
    });

    test('a category cannot be given a piggy bank, or pig, icon', () {
      expect(categoryIcons.keys, isNot(contains('savings')));
      expect(categoryIcons.keys.where((k) => k.contains('pig')), isEmpty);
    });

    test('a goal cannot be given a piggy bank icon', () {
      expect(goalIcons, isNot(contains('savings')));
      expect(goalIcons, contains(defaultGoalIcon));
    });

    test('an old category with the piggy bank key shows a plain icon', () {
      expect(categoryIconFor('savings'), categoryIconFor('category'));
    });
  });
}
