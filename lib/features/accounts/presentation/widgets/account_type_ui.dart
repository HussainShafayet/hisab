import 'package:flutter/material.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

extension AccountTypeUi on AccountType {
  String get label => switch (this) {
    AccountType.cash => 'Cash',
    AccountType.mobileBanking => 'Mobile banking',
    AccountType.bank => 'Bank',
    AccountType.card => 'Card',
  };

  IconData get icon => switch (this) {
    AccountType.cash => Icons.payments_outlined,
    AccountType.mobileBanking => Icons.smartphone,
    AccountType.bank => Icons.account_balance_outlined,
    AccountType.card => Icons.credit_card,
  };
}
