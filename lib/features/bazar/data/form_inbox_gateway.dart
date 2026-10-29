import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why the answers of the form could not be read.
enum FormInboxProblem {
  noInternet,

  /// Google showed a page instead of the CSV: the sheet is not published.
  notPublished,
  failed,
}

class FormInboxException implements Exception {
  const FormInboxException(this.problem, [this.detail]);

  final FormInboxProblem problem;
  final String? detail;

  @override
  String toString() => 'FormInboxException($problem, $detail)';
}

/// Reads the published responses sheet of a Google Form as CSV text. Behind an
/// interface so tests can give the app a fake one.
abstract interface class FormInboxGateway {
  /// The CSV at [uri]. Throws [FormInboxException].
  Future<String> fetch(Uri uri);
}

class HttpFormInboxGateway implements FormInboxGateway {
  const HttpFormInboxGateway();

  @override
  Future<String> fetch(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode >= 400) {
        // A sheet that is not shared answers with an error page too.
        throw FormInboxException(
          response.statusCode == 404 || response.statusCode == 403
              ? FormInboxProblem.notPublished
              : FormInboxProblem.failed,
          'HTTP ${response.statusCode}',
        );
      }
      final start = text.trimLeft().toLowerCase();
      if (start.startsWith('<!doctype') || start.startsWith('<html')) {
        throw const FormInboxException(FormInboxProblem.notPublished);
      }
      return text;
    } on SocketException {
      throw const FormInboxException(FormInboxProblem.noInternet);
    } on HandshakeException {
      throw const FormInboxException(FormInboxProblem.noInternet);
    } on HttpException {
      throw const FormInboxException(FormInboxProblem.noInternet);
    } on TimeoutException {
      throw const FormInboxException(FormInboxProblem.noInternet);
    } finally {
      client.close(force: true);
    }
  }
}

final formInboxGatewayProvider = Provider<FormInboxGateway>(
  (ref) => const HttpFormInboxGateway(),
);
