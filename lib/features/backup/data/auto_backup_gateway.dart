import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Why the phone would not keep the automatic backup.
enum AutoBackupProblem {
  /// The phone has Android 9 or older: no folder to put the file in.
  oldAndroid,

  /// Anything else, such as full storage.
  failed,
}

class AutoBackupException implements Exception {
  const AutoBackupException(this.problem);

  final AutoBackupProblem problem;
}

/// Puts a file in the phone's Downloads folder, where it stays when the app is
/// removed. Behind an interface so tests can give the app a fake one.
abstract interface class AutoBackupGateway {
  /// Writes [bytes] as Downloads/Hishab/[name], over the file of the same name
  /// this app wrote before. Throws [AutoBackupException].
  Future<void> saveToDownloads(String name, Uint8List bytes);
}

class ChannelAutoBackupGateway implements AutoBackupGateway {
  const ChannelAutoBackupGateway();

  static const _channel = MethodChannel('hishab/auto_backup');

  @override
  Future<void> saveToDownloads(String name, Uint8List bytes) async {
    try {
      await _channel.invokeMethod<String>('saveToDownloads', {
        'name': name,
        'bytes': bytes,
      });
    } on PlatformException catch (error) {
      throw AutoBackupException(
        error.code == 'old_android'
            ? AutoBackupProblem.oldAndroid
            : AutoBackupProblem.failed,
      );
    } on MissingPluginException {
      throw const AutoBackupException(AutoBackupProblem.failed);
    }
  }
}

final autoBackupGatewayProvider = Provider<AutoBackupGateway>(
  (ref) => const ChannelAutoBackupGateway(),
);
