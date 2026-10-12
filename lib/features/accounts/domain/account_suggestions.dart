import 'package:hishab/features/accounts/domain/account_type.dart';

/// Names to offer as one-tap choices when making an account of [type], so
/// the usual ones (bKash, Nagad, a card) need no typing.
List<String> accountNameSuggestions(AccountType type) => switch (type) {
  AccountType.cash => const ['Cash', 'Wallet', 'Home cash'],
  AccountType.mobileBanking => const ['bKash', 'Nagad', 'Rocket', 'Upay'],
  AccountType.bank => const [
    'Bank account',
    'Savings account',
    'DPS',
    'Dutch-Bangla Bank',
    'BRAC Bank',
    'City Bank',
  ],
  AccountType.card => const ['Debit card', 'Credit card', 'Visa', 'Mastercard'],
};
