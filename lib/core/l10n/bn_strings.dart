import 'package:hishab/core/l10n/bn_bazar.dart';
import 'package:hishab/core/l10n/bn_core.dart';
import 'package:hishab/core/l10n/bn_daily.dart';
import 'package:hishab/core/l10n/bn_debts.dart';
import 'package:hishab/core/l10n/bn_dollars.dart';
import 'package:hishab/core/l10n/bn_errors.dart';
import 'package:hishab/core/l10n/bn_goals.dart';
import 'package:hishab/core/l10n/bn_insights.dart';
import 'package:hishab/core/l10n/bn_recurring.dart';
import 'package:hishab/core/l10n/bn_split.dart';
import 'package:hishab/core/l10n/bn_tags.dart';
import 'package:hishab/core/l10n/bn_zakat.dart';

/// Bangla for the texts of the app, by their English text. See `tr`.
///
/// Each feature keeps its own map (`bn_<feature>.dart`) and it is merged here.
const bnStrings = <String, String>{
  ...bnBazar,
  ...bnCore,
  ...bnDaily,
  ...bnDebts,
  ...bnDollars,
  ...bnErrors,
  ...bnGoals,
  ...bnInsights,
  ...bnRecurring,
  ...bnSplit,
  ...bnTags,
  ...bnZakat,
};
