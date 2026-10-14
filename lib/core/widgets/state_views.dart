import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/fun/domain/takka_mood.dart';
import 'package:hishab/features/fun/presentation/widgets/takka.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// Shown when a list or screen has no data yet.
class EmptyState extends ConsumerWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? message;

  /// Optional call to action, e.g. a `FilledButton`.
  final Widget? action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fun = ref.watch(preferencesProvider).funMode;
    // Scrolls when the screen is too small for it (large text, small phone).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Takka keeps the screen company; without Fun mode, the plain icon.
            if (fun)
              const Takka(mood: TakkaMood.sleepy, size: 88)
            else
              Icon(icon, size: 64, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

/// Shown while data is being loaded.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Shown when loading failed. Pass [onRetry] to show a retry button.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: tr('Something went wrong'),
      message: message,
      action: onRetry == null
          ? null
          : FilledButton.tonal(onPressed: onRetry, child: Text(tr('Retry'))),
    );
  }
}
