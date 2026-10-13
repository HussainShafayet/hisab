import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/core/utils/validation_exception.dart';

void main() {
  group('describeError', () {
    test('uses the words of a validation error as they are', () {
      expect(
        describeError(const ValidationException('Enter a name.')),
        'Enter a name.',
      );
    });

    test('uses the words of a rate error as they are', () {
      expect(
        describeError(const RateException('No rate today.')),
        'No rate today.',
      );
    });

    test('says there is no internet for network trouble', () {
      const expected = 'No internet. Check your connection and try again.';
      expect(describeError(const SocketException('x')), expected);
      expect(describeError(TimeoutException('x')), expected);
      expect(describeError(const HttpException('x')), expected);
    });

    test('says a file could not be read or saved', () {
      expect(
        describeError(const FileSystemException('disk full')),
        'The file could not be read or saved. Check the storage and try again.',
      );
    });

    test('puts the usual database failures in plain words', () {
      expect(
        describeError(
          Exception(
            'SqliteException(2067): UNIQUE constraint failed: tags.name',
          ),
        ),
        'That is already there, so it cannot be saved again.',
      );
      expect(
        describeError(Exception('FOREIGN KEY constraint failed')),
        'This is still used somewhere else, so it cannot be removed.',
      );
      expect(
        describeError(Exception('database is locked')),
        'The database is busy. Please try again in a moment.',
      );
    });

    test('says something went wrong, with the reason, for anything else', () {
      expect(
        describeError(StateError('no element')),
        'Something went wrong. Please try again. (no element)',
      );
      expect(
        describeError(Exception('boom')),
        'Something went wrong. Please try again. (boom)',
      );
    });

    test('keeps the reason short', () {
      final text = describeError(Exception('x' * 500));

      expect(text.length, lessThan(200));
      expect(text, contains('…'));
    });

    test('says something went wrong even when there is no reason', () {
      expect(
        describeError(Exception('')),
        'Something went wrong. Please try again.',
      );
    });
  });
}
