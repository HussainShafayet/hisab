import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/features/settings/presentation/providers/settings_providers.dart';

/// How long a tapped income stays on screen before it is hidden again.
const incomeRevealDuration = Duration(seconds: 5);

/// Whether the person tapped the hidden income and it is on show for a few
/// seconds.
class IncomeReveal extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    ref.onDispose(() => _timer?.cancel());
    return false;
  }

  void reveal() {
    _timer?.cancel();
    state = true;
    _timer = Timer(incomeRevealDuration, () => state = false);
  }
}

final incomeRevealProvider = NotifierProvider<IncomeReveal, bool>(
  IncomeReveal.new,
);

/// True while income is to be drawn as dots: the setting is on and the person
/// has not just tapped it.
final incomeHiddenProvider = Provider<bool>(
  (ref) =>
      ref.watch(preferencesProvider.select((p) => p.hideIncome)) &&
      !ref.watch(incomeRevealProvider),
);
