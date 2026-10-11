import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The current time. Read it as `ref.read(clockProvider)()`. Tests override it
/// with a fixed time so "today" and "this month" do not depend on the day the
/// tests are run.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
