import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/fun/domain/quips.dart';
import 'package:hishab/features/fun/presentation/widgets/takka.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// On Home: Takka the coin with something to say about how the money is doing.
/// Tap Takka for another line. Not shown when Fun mode is off.
class TakkaCard extends ConsumerStatefulWidget {
  const TakkaCard({required this.inputs, super.key});

  final QuipInputs inputs;

  @override
  ConsumerState<TakkaCard> createState() => _TakkaCardState();
}

class _TakkaCardState extends ConsumerState<TakkaCard> {
  var _nudge = 0;

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(preferencesProvider).funMode) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final quip = pickQuip(widget.inputs, nudge: _nudge);

    return Padding(
      key: const ValueKey('takka-card'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Takka(
            mood: quip.mood,
            size: 64,
            onTap: () => setState(() => _nudge++),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  tr(quip.text),
                  key: ValueKey(quip.text),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
