import 'package:hishab/core/l10n/app_language.dart';
import 'package:hishab/core/l10n/bn_strings.dart';
import 'package:intl/intl.dart';

/// Texts are written in English where they are used and passed through [tr],
/// which looks them up in the Bangla dictionary when the app is in Bangla. A
/// text with no entry is shown in English, so a missing translation shows
/// instead of breaking anything.
///
/// The current language is plain state here, not something a widget looks up
/// through its context. That keeps [tr] usable everywhere (enum labels,
/// validation messages) and the app rebuilds its whole tree when the language
/// changes (see `HishabApp`).
AppLanguage _language = AppLanguage.english;

AppLanguage get appLanguage => _language;

bool get isBangla => _language == AppLanguage.bangla;

/// Switches the language of [tr], of numbers (see [localizeDigits]) and of
/// dates and months, which `intl` writes in the default locale.
void setAppLanguage(AppLanguage language) {
  _language = language;
  Intl.defaultLocale = language.code;
}

/// Translates [english]. Placeholders like `{count}` are filled from [args]
/// after the lookup, so a translation can move them around:
/// `tr('{count} accounts included', {'count': 3})`. In Bangla the digits of
/// the result are Bengali (০-৯).
String tr(String english, [Map<String, Object?> args = const {}]) {
  var text = isBangla ? (bnStrings[english] ?? english) : english;
  args.forEach((name, value) => text = text.replaceAll('{$name}', '$value'));
  return localizeDigits(text);
}

/// A count with its noun, in the right form: `plural(3, '1 account',
/// '{n} accounts')` is `3 accounts`, and `plural(1, ...)` is `1 account`.
/// Both forms are looked up in the dictionary, so Bangla can say them its way.
String plural(int n, String one, String other) =>
    n == 1 ? tr(one) : tr(other, {'n': n});

const _bengaliDigits = '০১২৩৪৫৬৭৮৯';

/// [text] with its digits written as Bengali digits when the app is in
/// Bangla, and unchanged otherwise. For showing numbers; never for data that
/// is saved, exported or parsed.
String localizeDigits(String text) {
  if (!isBangla) return text;
  final buffer = StringBuffer();
  for (final unit in text.split('')) {
    final digit = unit.codeUnitAt(0) - 0x30;
    buffer.write(
      digit >= 0 && digit <= 9 && unit.length == 1
          ? _bengaliDigits[digit]
          : unit,
    );
  }
  return buffer.toString();
}
