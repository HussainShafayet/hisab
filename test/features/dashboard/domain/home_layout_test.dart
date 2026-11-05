import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/dashboard/domain/home_layout.dart';
import 'package:hishab/features/dashboard/domain/setup_steps.dart';

void main() {
  group('the sections put away', () {
    test('are read from the saved names, ignoring unknown ones', () {
      expect(parseHiddenSections('plans,recent,nonsense'), {
        HomeSection.plans,
        HomeSection.recent,
      });
      expect(parseHiddenSections(null), isEmpty);
      expect(parseHiddenSections(''), isEmpty);
    });

    test('are saved in a fixed order', () {
      expect(
        encodeHiddenSections({HomeSection.recent, HomeSection.shortcuts}),
        'shortcuts,recent',
      );
    });

    test('one can be put away and brought back', () {
      final away = withSectionHidden({}, HomeSection.plans, away: true);
      expect(away, {HomeSection.plans});
      expect(withSectionHidden(away, HomeSection.plans, away: false), isEmpty);
    });
  });

  group('the setup steps', () {
    test('nothing done yet: the first entry is next', () {
      final progress = setupProgressOf(
        hasEntry: false,
        hasBudget: false,
        hasBackup: false,
        driveOn: false,
      );
      expect(progress.doneCount, 0);
      expect(progress.total, 4);
      expect(progress.next, SetupStep.firstEntry);
      expect(progress.isComplete, isFalse);
    });

    test('the next one skips what is already done', () {
      final progress = setupProgressOf(
        hasEntry: true,
        hasBudget: false,
        hasBackup: true,
        driveOn: false,
      );
      expect(progress.next, SetupStep.budget);
      expect(progress.doneCount, 2);
    });

    test('all done is complete with nothing next', () {
      final progress = setupProgressOf(
        hasEntry: true,
        hasBudget: true,
        hasBackup: true,
        driveOn: true,
      );
      expect(progress.isComplete, isTrue);
      expect(progress.next, isNull);
    });
  });
}
