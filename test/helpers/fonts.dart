import 'dart:io';

import 'package:flutter/services.dart';

const _bengaliFont =
    '/usr/share/fonts/google-noto-vf/NotoSansBengali[wght].ttf';

/// Loads Roboto and the Material icons from the Flutter SDK, plus a Bengali
/// font from the system when there is one.
///
/// `flutter test` draws all text with "Ahem", where every letter is a square.
/// That makes text much wider than on a phone, so a test about how text fits
/// (does a label wrap, does a button overflow) needs the real font. Call it
/// inside `tester.runAsync`, because it reads files.
Future<void> loadRealFonts() async {
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      '${Platform.environment['HOME']}/development/flutter';
  final fonts = '$flutterRoot/bin/cache/artifacts/material_fonts';

  Future<ByteData> read(String path) async =>
      ByteData.sublistView(await File(path).readAsBytes());

  final loaders = [
    FontLoader('Roboto')
      ..addFont(read('$fonts/Roboto-Regular.ttf'))
      ..addFont(read('$fonts/Roboto-Medium.ttf'))
      ..addFont(read('$fonts/Roboto-Bold.ttf')),
    FontLoader('MaterialIcons')
      ..addFont(read('$fonts/MaterialIcons-Regular.otf')),
    if (File(_bengaliFont).existsSync())
      FontLoader('NotoSansBengali')..addFont(read(_bengaliFont)),
  ];
  await Future.wait([for (final loader in loaders) loader.load()]);
}
