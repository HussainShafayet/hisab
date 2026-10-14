import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/widgets/confetti.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// Throws confetti for something worth it (a goal reached, a loan paid off),
/// unless Fun mode is off or the phone asks for no animations.
void celebrate(BuildContext context, WidgetRef ref) {
  if (!ref.read(preferencesProvider).funMode) return;
  showConfetti(context);
}
