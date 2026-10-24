import 'dart:typed_data';

import 'package:hishab/features/backup/data/drive_gateway.dart';

/// A Google Drive for tests: it keeps the files in memory, knows whether
/// someone signed in, and can be told to fail.
class FakeDriveGateway implements DriveGateway {
  String email = 'me@gmail.com';

  /// Whether an account is signed in on this "phone".
  bool signedIn = false;

  /// When set, [signIn] throws this.
  DriveProblem? signInFails;

  /// When set, [upload] throws this.
  DriveProblem? uploadFails;

  /// What [download] returns.
  DriveFile? file;

  var signInCalls = 0;
  var signOutCalls = 0;
  final uploads = <({String name, Uint8List bytes})>[];

  @override
  Future<String> signIn() async {
    signInCalls++;
    final problem = signInFails;
    if (problem != null) throw DriveException(problem);
    signedIn = true;
    return email;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    signedIn = false;
  }

  @override
  Future<void> upload(String name, Uint8List bytes) async {
    if (!signedIn) throw const DriveException(DriveProblem.needsSignIn);
    final problem = uploadFails;
    if (problem != null) throw DriveException(problem, 'HTTP 403 test');
    uploads.add((name: name, bytes: bytes));
  }

  @override
  Future<DriveFile?> download(String name) async {
    if (!signedIn) throw const DriveException(DriveProblem.needsSignIn);
    return file;
  }
}
