import 'package:hishab/core/notifications/alert_kind.dart';

/// What an alert plays when it comes.
enum AlertSoundMode {
  /// Its own funny sound.
  funny,

  /// The phone's usual notification sound.
  phone,

  /// No sound and no buzz; the alert only shows in the notification shade.
  silent,
}

/// The setting that holds the sound of [kind] (`sound_bill`). It is only there
/// when the person chose one for this alert; else the general choice (funny
/// sounds on or off) counts.
String alertSoundKey(AlertKind kind) => 'sound_${kind.channelId}';

/// The sounds the person chose for single alerts, from the saved settings.
Map<AlertKind, AlertSoundMode> alertSoundOverrides(Map<String, String> saved) {
  final result = <AlertKind, AlertSoundMode>{};
  for (final kind in AlertKind.values) {
    final name = saved[alertSoundKey(kind)];
    final mode = AlertSoundMode.values
        .where((mode) => mode.name == name)
        .firstOrNull;
    if (mode != null) result[kind] = mode;
  }
  return result;
}

/// What [kind] plays: its own choice, else the general one.
AlertSoundMode effectiveSound(
  AlertKind kind, {
  required bool funSounds,
  Map<AlertKind, AlertSoundMode> overrides = const {},
}) =>
    overrides[kind] ??
    (funSounds ? AlertSoundMode.funny : AlertSoundMode.phone);
