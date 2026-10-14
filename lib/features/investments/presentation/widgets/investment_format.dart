import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/features/investments/domain/investment.dart';

/// What an investment has made, with a plus for a gain: `+৳1,500.00`.
String formatReturn(int amount) =>
    amount > 0 ? '+${formatPoisha(amount)}' : formatPoisha(amount);

/// The return as a percent of the money put in, with a plus for a gain:
/// `+15%`. Empty when nothing was put in.
String formatRoi(int? percent) {
  if (percent == null) return '';
  return localizeDigits('${percent > 0 ? '+' : ''}$percent%');
}

String kindLabel(InvestmentEntryKind kind) => switch (kind) {
  InvestmentEntryKind.putIn => tr('Put in'),
  InvestmentEntryKind.profit => tr('Profit'),
  InvestmentEntryKind.takeBack => tr('Taken back'),
};
