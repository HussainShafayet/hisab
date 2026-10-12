import 'package:hishab/core/l10n/bn_core.dart';
import 'package:hishab/core/l10n/bn_debts.dart';
import 'package:hishab/core/l10n/bn_recurring.dart';

/// Bangla for the texts of the app, by their English text. See `tr`.
///
/// Each feature keeps its own map (`bn_<feature>.dart`) and it is merged here.
const bnStrings = <String, String>{...bnCore, ...bnDebts, ...bnRecurring};
