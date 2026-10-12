import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

extension AccountTypeUi on AccountType {
  String get label => switch (this) {
    AccountType.cash => tr('Cash'),
    AccountType.mobileBanking => tr('Mobile banking'),
    AccountType.bank => tr('Bank'),
    AccountType.card => tr('Debit card'),
    AccountType.creditCard => tr('Credit card'),
  };

  /// The color of the account's card. Dark enough for white text on it.
  Color get color => switch (this) {
    AccountType.cash => const Color(0xFF2E7D32),
    AccountType.mobileBanking => const Color(0xFFAD1457),
    AccountType.bank => const Color(0xFF1565C0),
    AccountType.card => const Color(0xFF5E35B1),
    AccountType.creditCard => const Color(0xFFD84315),
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.mobileBanking => Icons.smartphone,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.card => Icons.payment,
    AccountType.creditCard => Icons.credit_card,
  };
}
