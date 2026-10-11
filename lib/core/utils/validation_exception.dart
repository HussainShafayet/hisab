/// Thrown by repositories when input breaks a business rule (blank name,
/// duplicate name, ...). The [message] is written for the user and can be
/// shown as is.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}

/// The text to show the user for [error]: the message of a
/// [ValidationException], or the error itself for anything unexpected.
String describeError(Object error) =>
    error is ValidationException ? error.message : '$error';
