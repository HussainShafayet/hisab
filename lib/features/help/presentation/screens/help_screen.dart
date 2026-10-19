import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/help/domain/guide.dart';
import 'package:hishab/features/help/domain/guide_content.dart';

/// The user guide: a place to start, every part of the app by group, and a
/// search over all of it.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim();
    final found = searchGuide(guideTopics, query);

    return Scaffold(
      appBar: AppBar(title: Text(tr('Help & guide'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              key: const ValueKey('help-search'),
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: tr('Search the guide'),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        key: const ValueKey('help-search-clear'),
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (query.isNotEmpty) ...[
            if (found.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  tr('Nothing in the guide matches that.'),
                  key: const ValueKey('help-no-match'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            for (final topic in found) _TopicTile(topic: topic),
          ] else
            for (final group in guideGroups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  tr(group.title),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              for (final topic in guideTopics.where((t) => t.group == group.id))
                _TopicTile(topic: topic),
            ],
        ],
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final GuideTopic topic;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey('help-topic-${topic.id}'),
      leading: Icon(topic.icon),
      title: Text(tr(topic.title)),
      subtitle: Text(tr(topic.summary)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(AppRoutes.helpTopic(topic.id)),
    );
  }
}
