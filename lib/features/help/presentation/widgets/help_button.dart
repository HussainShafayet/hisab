import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/router/app_routes.dart';

/// The ? at the top of a screen. It opens the guide for that screen, the
/// topic called [topic] (see `guide_content.dart`).
class HelpButton extends StatelessWidget {
  const HelpButton(this.topic, {super.key});

  final String topic;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: ValueKey('help-$topic'),
      tooltip: tr('How this works'),
      icon: const Icon(Icons.help_outline),
      onPressed: () => context.push(AppRoutes.helpTopic(topic)),
    );
  }
}
