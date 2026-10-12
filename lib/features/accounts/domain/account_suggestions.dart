import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

/// Names to offer as one-tap choices when making an account of [type], so
/// the usual ones (bKash, Nagad, a card) need no typing.
List<String> accountNameSuggestions(AccountType type) => switch (type) {
  AccountType.cash => [tr('Cash'), tr('Wallet'), tr('Home cash')],
  AccountType.mobileBanking => const ['bKash', 'Nagad', 'Rocket', 'Upay'],
  AccountType.bank => [
    tr('Bank account'),
    tr('Savings account'),
    'DPS',
    'Dutch-Bangla Bank',
    'BRAC Bank',
    'City Bank',
  ],
  AccountType.card => [tr('Debit card'), 'Visa', 'Mastercard'],
  AccountType.creditCard => [tr('Credit card'), 'Visa', 'Mastercard'],
};
