import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The OAuth client of the Google Cloud project "Hishab" that is made for the
/// web: Android's sign-in needs it as `serverClientId`. It is an identifier, not
/// a secret. The Android client of the same project is found by the package
/// name and the signing key of the app.
const driveWebClientId =
    '328929839309-d6497a2q1eqhigi2khov2ub1tcraj5bg.apps.googleusercontent.com';

/// Only the files this app makes in the person's Drive.
const driveScope = 'https://www.googleapis.com/auth/drive.file';

/// The name of the backup file in Google Drive.
const driveBackupFileName = 'Hishab-backup.json';

/// Why Google Drive did not take or give the backup.
enum DriveProblem {
  /// The person closed the Google sign-in.
  cancelled,

  /// Nobody is signed in, or Google asks to sign in again.
  needsSignIn,
  noInternet,

  /// Google refused: the Drive API or the OAuth settings of the project.
  notAllowed,
  failed,
}

class DriveException implements Exception {
  const DriveException(this.problem, [this.detail]);

  final DriveProblem problem;

  /// A short line from Google, for finding out what went wrong.
  final String? detail;

  @override
  String toString() => 'DriveException($problem, $detail)';
}

/// A file read from Google Drive.
class DriveFile {
  const DriveFile({required this.bytes, required this.modified});

  final Uint8List bytes;
  final DateTime? modified;
}

/// The person's Google Drive, behind an interface so tests can give the app a
/// fake one. Every method throws [DriveException].
abstract interface class DriveGateway {
  /// Asks the person to choose a Google account and allow Hishab to keep its
  /// own files in Drive. Returns the email of the account.
  Future<String> signIn();

  /// Forgets the account on this phone.
  Future<void> signOut();

  /// Writes [bytes] as [name], over the file of that name Hishab made before.
  /// Does not ask anything: throws [DriveProblem.needsSignIn] when it would
  /// have to.
  Future<void> upload(String name, Uint8List bytes);

  /// The newest file of that name Hishab made, or null when there is none.
  Future<DriveFile?> download(String name);
}

class GoogleDriveGateway implements DriveGateway {
  GoogleDriveGateway();

  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    await GoogleSignIn.instance.initialize(serverClientId: driveWebClientId);
    _ready = true;
  }

  @override
  Future<String> signIn() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance.authenticate(
        scopeHint: const [driveScope],
      );
      await account.authorizationClient.authorizeScopes(const [driveScope]);
      return account.email;
    } on GoogleSignInException catch (error) {
      throw DriveException(
        error.code == GoogleSignInExceptionCode.canceled
            ? DriveProblem.cancelled
            : DriveProblem.failed,
        '${error.code.name} ${error.description ?? ''}'.trim(),
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } on Object {
      // Forgetting the account is a favour: nothing depends on it.
    }
  }

  /// The headers of a request, from the account that is signed in, without
  /// asking the person anything.
  Future<Map<String, String>> _headers() async {
    try {
      await _init();
      final account = await GoogleSignIn.instance
          .attemptLightweightAuthentication();
      final headers = await account?.authorizationClient.authorizationHeaders(
        const [driveScope],
      );
      if (headers == null) throw const DriveException(DriveProblem.needsSignIn);
      return headers;
    } on GoogleSignInException catch (error) {
      throw DriveException(
        DriveProblem.needsSignIn,
        '${error.code.name} ${error.description ?? ''}'.trim(),
      );
    }
  }

  /// One request to Google Drive. Returns the status and the body.
  Future<(int, Uint8List)> _send(
    String method,
    Uri uri, {
    Map<String, String> extra = const {},
    List<int>? body,
  }) async {
    final headers = await _headers();
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final request = await client.openUrl(method, uri);
      headers.forEach(request.headers.set);
      extra.forEach(request.headers.set);
      if (body != null) {
        request.contentLength = body.length;
        request.add(body);
      }
      final response = await request.close().timeout(
        const Duration(seconds: 60),
      );
      final bytes = await response.fold<BytesBuilder>(
        BytesBuilder(copy: false),
        (builder, chunk) => builder..add(chunk),
      );
      final data = bytes.takeBytes();
      final status = response.statusCode;
      if (status == 401) {
        throw const DriveException(DriveProblem.needsSignIn, 'HTTP 401');
      }
      if (status == 403) {
        throw DriveException(DriveProblem.notAllowed, _short(data, 403));
      }
      if (status >= 400) {
        throw DriveException(DriveProblem.failed, _short(data, status));
      }
      return (status, data);
    } on SocketException {
      throw const DriveException(DriveProblem.noInternet);
    } on HandshakeException {
      throw const DriveException(DriveProblem.noInternet);
    } on HttpException {
      throw const DriveException(DriveProblem.noInternet);
    } on TimeoutException {
      throw const DriveException(DriveProblem.noInternet);
    } finally {
      client.close(force: true);
    }
  }

  /// The first words of an error from Google.
  String _short(Uint8List body, int status) {
    var text = utf8.decode(body, allowMalformed: true);
    try {
      final error = (jsonDecode(text) as Map)['error'];
      if (error is Map && error['message'] is String) {
        text = error['message'] as String;
      }
    } on Object {
      // Not JSON: use it as it is.
    }
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length > 160) text = text.substring(0, 160);
    return 'HTTP $status $text'.trim();
  }

  Future<({String id, DateTime? modified})?> _find(String name) async {
    final query = "name = '$name' and trashed = false";
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files', {
      'q': query,
      'fields': 'files(id,modifiedTime)',
      'orderBy': 'modifiedTime desc',
      'pageSize': '1',
    });
    final (_, body) = await _send('GET', uri);
    final files = (jsonDecode(utf8.decode(body)) as Map)['files'] as List;
    if (files.isEmpty) return null;
    final file = files.first as Map;
    return (
      id: file['id'] as String,
      modified: DateTime.tryParse('${file['modifiedTime']}')?.toLocal(),
    );
  }

  @override
  Future<void> upload(String name, Uint8List bytes) async {
    final existing = await _find(name);
    if (existing != null) {
      final uri = Uri.https(
        'www.googleapis.com',
        '/upload/drive/v3/files/${existing.id}',
        {'uploadType': 'media'},
      );
      await _send(
        'PATCH',
        uri,
        extra: const {'Content-Type': 'application/json'},
        body: bytes,
      );
      return;
    }
    const boundary = 'hishab-backup-boundary';
    final body = BytesBuilder()
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset=UTF-8\r\n\r\n'
          '${jsonEncode({'name': name, 'mimeType': 'application/json'})}\r\n'
          '--$boundary\r\n'
          'Content-Type: application/json\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--'));
    final uri = Uri.https('www.googleapis.com', '/upload/drive/v3/files', {
      'uploadType': 'multipart',
    });
    await _send(
      'POST',
      uri,
      extra: const {'Content-Type': 'multipart/related; boundary=$boundary'},
      body: body.takeBytes(),
    );
  }

  @override
  Future<DriveFile?> download(String name) async {
    final file = await _find(name);
    if (file == null) return null;
    final uri = Uri.https('www.googleapis.com', '/drive/v3/files/${file.id}', {
      'alt': 'media',
    });
    final (_, body) = await _send('GET', uri);
    return DriveFile(bytes: body, modified: file.modified);
  }
}

final driveGatewayProvider = Provider<DriveGateway>(
  (ref) => GoogleDriveGateway(),
);
