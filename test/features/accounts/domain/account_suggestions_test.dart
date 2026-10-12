import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/accounts/domain/account_suggestions.dart';
import 'package:hishab/features/accounts/domain/account_type.dart';

void main() {
  test('every kind of account has suggestions', () {
    for (final type in AccountType.values) {
      expect(accountNameSuggestions(type), isNotEmpty, reason: type.name);
    }
  });

  test('mobile banking offers the usual services', () {
    expect(
      accountNameSuggestions(AccountType.mobileBanking),
      containsAll(['bKash', 'Nagad', 'Rocket']),
    );
  });

  test('cash starts with Cash', () {
    expect(accountNameSuggestions(AccountType.cash).first, 'Cash');
  });

  test('no suggestion repeats within a kind', () {
    for (final type in AccountType.values) {
      final names = accountNameSuggestions(type).map((n) => n.toLowerCase());
      expect(names.toSet().length, names.length, reason: type.name);
    }
  });

  test('every suggestion fits the longest name an account can have', () {
    for (final type in AccountType.values) {
      for (final name in accountNameSuggestions(type)) {
        expect(name.length, lessThanOrEqualTo(60));
        expect(name.trim(), name);
      }
    }
  });
}
