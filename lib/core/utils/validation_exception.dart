import 'dart:async';
import 'dart:io';

import 'package:hishab/core/l10n/translator.dart';

/// Thrown by repositories when input breaks a business rule (blank name,
/// duplicate name, ...). The [message] is written for the user and can be
/// shown as is.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// The longest technical reason shown after the plain words.
const _maxDetailLength = 140;

/// The text to show the user for [error].
///
/// A [ValidationException] already has words written for the person, and they
/// are used as they are. Anything else (a full disk, a database error, a bug)
/// is turned into plain words for the usual causes, or a short "something went
/// wrong" with the reason in brackets, so a problem never shows as a raw error
/// and never as nothing at all.
String describeError(Object error) {
  if (error is ValidationException) return error.message;
  if (error is SocketException ||
      error is TimeoutException ||
      error is HttpException) {
    return tr('No internet. Check your connection and try again.');
  }
  if (error is FileSystemException) {
    return tr(
      'The file could not be read or saved. Check the storage and try again.',
    );
  }
  final text = '$error';
  if (text.contains('UNIQUE constraint')) {
    return tr('That is already there, so it cannot be saved again.');
  }
  if (text.contains('FOREIGN KEY constraint')) {
    return tr('This is still used somewhere else, so it cannot be removed.');
  }
  if (text.contains('database is locked')) {
    return tr('The database is busy. Please try again in a moment.');
  }
  var detail = text
      .replaceFirst(RegExp(r'^(Exception|Error|Bad state): '), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (detail.length > _maxDetailLength) {
    detail = '${detail.substring(0, _maxDetailLength - 1)}…';
  }
  return detail.isEmpty
      ? tr('Something went wrong. Please try again.')
      : tr('Something went wrong. Please try again. ({detail})', {
          'detail': detail,
        });
}
