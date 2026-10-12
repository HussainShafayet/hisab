import 'dart:ui' show Locale;

/// The languages the app can be shown in.
enum AppLanguage {
  english('en', 'English'),
  bangla('bn', 'বাংলা');

  const AppLanguage(this.code, this.nativeName);

  /// The language code, also the name of its locale.
  final String code;

  /// The language written in itself, so it can be found whatever the app is
  /// currently set to.
  final String nativeName;

  Locale get locale => Locale(code);
}
