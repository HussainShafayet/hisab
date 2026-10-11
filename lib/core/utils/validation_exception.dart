/// Thrown by repositories when input breaks a business rule (blank name,
/// duplicate name, ...). The [message] is written for the user and can be
/// shown as is.
class ValidationException implements Exception {
  const ValidationException(this.message);

  final String message;

  @override
  String toString() => 'ValidationException: $message';
}
