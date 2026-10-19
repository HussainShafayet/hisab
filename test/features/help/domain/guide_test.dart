import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/help/domain/guide.dart';
import 'package:hishab/features/help/domain/guide_content.dart';

void main() {
  tearDown(() => setAppLanguage(AppLanguage.english));

  group('the guide', () {
    test('has topics with different ids', () {
      final ids = guideTopics.map((t) => t.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, contains('start'));
      expect(ids, contains('faq'));
    });

    test('lists every topic under a group that exists', () {
      final groups = guideGroups.map((g) => g.id).toSet();

      for (final topic in guideTopics) {
        expect(groups, contains(topic.group), reason: topic.id);
      }
      for (final group in guideGroups) {
        expect(
          guideTopics.where((t) => t.group == group.id),
          isNotEmpty,
          reason: group.id,
        );
      }
    });

    test('has real text in every topic', () {
      for (final topic in guideTopics) {
        expect(topic.title.trim(), isNotEmpty, reason: topic.id);
        expect(topic.summary.trim(), isNotEmpty, reason: topic.id);
        expect(topic.sections, isNotEmpty, reason: topic.id);
        for (final section in topic.sections) {
          expect(section.heading.trim(), isNotEmpty, reason: topic.id);
          expect(section.points, isNotEmpty, reason: topic.id);
          for (final point in section.points) {
            expect(point.trim().length, greaterThan(15), reason: point);
          }
        }
      }
    });

    test('opens a place in the app that exists', () {
      final known = {
        AppRoutes.transactions,
        AppRoutes.budget,
        AppRoutes.reports,
        AppRoutes.accounts,
        AppRoutes.categories,
        AppRoutes.backup,
        AppRoutes.settings,
        AppRoutes.debts,
        AppRoutes.tags,
        AppRoutes.investments,
        AppRoutes.goals,
        AppRoutes.recurring,
        AppRoutes.splitBill,
        AppRoutes.bazar,
        AppRoutes.zakat,
        AppRoutes.metals,
        AppRoutes.badges,
      };

      for (final topic in guideTopics) {
        if (topic.route != null) {
          expect(known, contains(topic.route), reason: topic.id);
        }
      }
    });

    // The rule of the guide: a feature without a topic is a feature nobody can
    // learn about. Adding a screen to More means adding a topic here.
    test('covers every feature on the More screen and the main tabs', () {
      final routes = guideTopics.map((t) => t.route).toSet();

      for (final route in [
        AppRoutes.transactions,
        AppRoutes.budget,
        AppRoutes.reports,
        AppRoutes.accounts,
        AppRoutes.categories,
        AppRoutes.debts,
        AppRoutes.goals,
        AppRoutes.investments,
        AppRoutes.bazar,
        AppRoutes.tags,
        AppRoutes.recurring,
        AppRoutes.splitBill,
        AppRoutes.zakat,
        AppRoutes.metals,
        AppRoutes.badges,
        AppRoutes.backup,
        AppRoutes.settings,
      ]) {
        expect(routes, contains(route), reason: route);
      }
    });

    test('numbers the steps of Start here', () {
      final start = guideTopicById(guideTopics, 'start')!;

      expect(start.sections.first.steps, isTrue);
      expect(start.sections.first.points, hasLength(5));
    });
  });

  group('looking something up', () {
    test('finds topics by a word in the title or the text', () {
      final byTitle = searchGuide(guideTopics, 'zakat').map((t) => t.id);
      final byText = searchGuide(guideTopics, 'nisab').map((t) => t.id);

      expect(byTitle, contains('zakat'));
      expect(byText, containsAll(['zakat', 'faq']));
    });

    test('needs every word, in any order and any case', () {
      expect(searchGuide(guideTopics, 'RICKSHAW alerts').map((t) => t.id), [
        'alerts',
      ]);
    });

    test('gives everything for an empty search, nothing for no match', () {
      expect(searchGuide(guideTopics, '  '), guideTopics);
      expect(searchGuide(guideTopics, 'xyzzyplugh'), isEmpty);
    });

    test('searches in Bangla when the app is in Bangla', () {
      setAppLanguage(AppLanguage.bangla);

      expect(
        searchGuide(guideTopics, 'যাকাত').map((t) => t.id),
        contains('zakat'),
      );
    });
  });
}
