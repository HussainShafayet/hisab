import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/percent.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  // Month names for Bangla have to be loaded before they can be used; the
  // app does it at startup.
  setUpAll(() => initializeDateFormatting('bn'));
  tearDown(() => setAppLanguage(AppLanguage.english));

  group('in English', () {
    setUp(() => setAppLanguage(AppLanguage.english));

    test('a text comes back as it was written', () {
      expect(tr('Home'), 'Home');
      expect(tr('Anything at all'), 'Anything at all');
    });

    test('placeholders are filled in', () {
      expect(
        tr('{count} accounts included', {'count': 3}),
        '3 accounts included',
      );
      expect(
        tr('Recorded {amount} income on {account}', {
          'amount': '৳50.00',
          'account': 'Cash',
        }),
        'Recorded ৳50.00 income on Cash',
      );
    });

    test('digits stay as they are', () {
      expect(
        localizeDigits('৳1,234.50 on 11/10/2026'),
        '৳1,234.50 on 11/10/2026',
      );
    });

    test('plural picks the one or the many form', () {
      expect(plural(1, '1 account', '{n} accounts'), '1 account');
      expect(plural(0, '1 account', '{n} accounts'), '0 accounts');
      expect(plural(3, '1 account', '{n} accounts'), '3 accounts');
    });

    test('says it is not Bangla', () {
      expect(isBangla, isFalse);
      expect(appLanguage, AppLanguage.english);
    });

    test('money and percent are written with ordinary digits', () {
      expect(formatPoisha(123450), '৳1,234.50');
      expect(formatPercent(1, 4), '25%');
    });
  });

  group('in Bangla', () {
    setUp(() => setAppLanguage(AppLanguage.bangla));

    test('a text is looked up', () {
      expect(tr('Home'), 'হোম');
      expect(tr('Transactions'), 'লেনদেন');
    });

    test('a text with no entry stays in English', () {
      expect(
        tr('Something nobody has translated'),
        'Something nobody has translated',
      );
    });

    test('placeholders are filled in after the lookup', () {
      expect(
        tr('{count} accounts included', {'count': 3}),
        '৩টি অ্যাকাউন্ট ধরা হয়েছে',
      );
      expect(
        tr('Recorded {amount} income on {account}', {
          'amount': '৳50.00',
          'account': 'নগদ',
        }),
        'নগদ-এ ৳৫০.০০ আয় লেখা হয়েছে',
      );
    });

    test('digits become Bengali digits', () {
      expect(localizeDigits('৳1,234.50'), '৳১,২৩৪.৫০');
      expect(localizeDigits('0123456789'), '০১২৩৪৫৬৭৮৯');
      expect(localizeDigits('no digits'), 'no digits');
    });

    test('plural uses the entries of the dictionary', () {
      expect(plural(1, '1 account', '{n} accounts'), '১টি অ্যাকাউন্ট');
      expect(plural(12, '1 account', '{n} accounts'), '১২টি অ্যাকাউন্ট');
    });

    test('money and percent are written with Bengali digits', () {
      expect(formatPoisha(123450), '৳১,২৩৪.৫০');
      expect(formatPoisha(-5000), '-৳৫০.০০');
      expect(formatPoisha(123450, symbol: false), '১,২৩৪.৫০');
      expect(formatPercent(1, 4), '২৫%');
      expect(formatPercent(1, 1000), '<১%');
    });

    test('text that is typed or saved is not changed', () {
      // Used for the amount field and for files: always 0-9.
      expect(poishaToInput(123450), '1234.50');
      expect(poishaToFixed(123450), '1234.50');
    });

    test('dates and months are written in Bangla', () {
      final text = DateFormat('d MMMM yyyy').format(DateTime(2026, 10, 11));

      expect(text, matches(RegExp(r'[\u0980-\u09FF]')));
      expect(text, isNot(contains('October')));
    });
  });

  group('setAppLanguage', () {
    test('also sets the locale that intl uses', () {
      setAppLanguage(AppLanguage.bangla);
      expect(Intl.defaultLocale, 'bn');

      setAppLanguage(AppLanguage.english);
      expect(Intl.defaultLocale, 'en');
    });
  });

  group('AppLanguage', () {
    test('has a code and a name in its own script', () {
      expect(AppLanguage.english.code, 'en');
      expect(AppLanguage.english.nativeName, 'English');
      expect(AppLanguage.bangla.code, 'bn');
      expect(AppLanguage.bangla.nativeName, 'বাংলা');
      expect(AppLanguage.bangla.locale.languageCode, 'bn');
    });
  });
}
