import 'package:flutter/widgets.dart';
import 'package:hishab/core/l10n/translator.dart';

/// A heading in the guide's list, with the topics under it.
class GuideGroup {
  const GuideGroup(this.id, this.title);

  final String id;

  /// In English; show it through `tr`.
  final String title;
}

/// A part of a topic: a heading and its points. With [steps] the points are
/// numbered, like a recipe.
class GuideSection {
  const GuideSection(this.heading, this.points, {this.steps = false});

  /// In English; show it through `tr`.
  final String heading;
  final List<String> points;
  final bool steps;
}

/// One page of the guide: a feature, or a part of the app.
class GuideTopic {
  const GuideTopic({
    required this.id,
    required this.icon,
    required this.group,
    required this.title,
    required this.summary,
    required this.sections,
    this.route,
  });

  /// What a help button names it by.
  final String id;
  final IconData icon;
  final String group;

  /// In English; show it through `tr`.
  final String title;
  final String summary;
  final List<GuideSection> sections;

  /// Where the feature is in the app, so the guide can open it.
  final String? route;
}

/// The topic with this id, or null.
GuideTopic? guideTopicById(List<GuideTopic> topics, String id) {
  for (final topic in topics) {
    if (topic.id == id) return topic;
  }
  return null;
}

/// Every text of a topic, in English.
Iterable<String> guideTextsOf(GuideTopic topic) sync* {
  yield topic.title;
  yield topic.summary;
  for (final section in topic.sections) {
    yield section.heading;
    yield* section.points;
  }
}

/// Topics that match [query] (any word of it, in the title, summary, headings
/// or points, as shown in the current language). All of them when the query is
/// empty.
List<GuideTopic> searchGuide(List<GuideTopic> topics, String query) {
  final words = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return topics;
  bool matches(GuideTopic topic) {
    final text = guideTextsOf(topic).map(tr).join(' ').toLowerCase();
    return words.every(text.contains);
  }

  return topics.where(matches).toList();
}
