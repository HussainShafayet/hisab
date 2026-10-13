import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/tags/domain/tag.dart';
import 'package:hishab/features/tags/presentation/providers/tags_providers.dart';
import 'package:hishab/features/tags/presentation/widgets/tag_name_dialog.dart';
import 'package:intl/intl.dart';

/// "12 Oct", or "12 Oct - 15 Oct" for a span of days; empty without a day.
String tagDatesText(TagSummary summary) {
  final first = summary.firstDate;
  final last = summary.lastDate;
  if (first == null || last == null) return '';
  final format = DateFormat('d MMM yyyy');
  final a = format.format(first);
  final b = format.format(last);
  return a == b ? a : '$a - $b';
}

/// The trips and events, each with what it cost in all.
class TagsScreen extends ConsumerWidget {
  const TagsScreen({super.key});

  Future<void> _newTag(BuildContext context, WidgetRef ref) {
    return showTagNameDialog(
      context,
      title: tr('New trip or event'),
      onSave: (name) async {
        await ref.read(tagsRepositoryProvider).createTag(name);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(tagSummariesProvider);
    final theme = Theme.of(context);
    final colors = context.financeColors;

    return Scaffold(
      appBar: AppBar(title: Text(tr('Trips & events'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newTag(context, ref),
        icon: const Icon(Icons.add),
        label: Text(tr('New tag')),
      ),
      body: summaries.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(message: describeError(error)),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.luggage_outlined,
              title: tr('No trips or events yet'),
              message: tr(
                'Tag expenses with a trip or an event, like a tour or Eid, '
                'to see what it cost in all.',
              ),
              action: FilledButton(
                onPressed: () => _newTag(context, ref),
                child: Text(tr('New tag')),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final item in list)
                ListTile(
                  key: ValueKey('tag-row-${item.tag.id}'),
                  onTap: () => context.push(AppRoutes.tag(item.tag.id)),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    child: const Icon(Icons.luggage_outlined),
                  ),
                  title: Text(
                    item.tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      plural(item.count, '1 transaction', '{n} transactions'),
                      if (tagDatesText(item).isNotEmpty) tagDatesText(item),
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.35,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatPoisha(item.expense),
                        key: ValueKey('tag-spent-${item.tag.id}'),
                        style: theme.textTheme.titleSmall?.tabular.copyWith(
                          color: item.expense > 0 ? colors.expense : null,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
