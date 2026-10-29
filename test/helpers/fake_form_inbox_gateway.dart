import 'package:hishab/features/bazar/data/form_inbox_gateway.dart';

/// The published answers of a Google Form for tests: the CSV text it is given,
/// and the addresses it was asked for.
class FakeFormInboxGateway implements FormInboxGateway {
  String csv = 'Timestamp,Item\n';

  /// When set, [fetch] throws this.
  FormInboxProblem? failWith;

  final fetched = <Uri>[];

  /// Adds the answers of [items], one row each, like Google Forms does.
  void answer(List<String> items) {
    for (final item in items) {
      csv += '10/25/2026 10:00:00,$item\n';
    }
  }

  @override
  Future<String> fetch(Uri uri) async {
    fetched.add(uri);
    final problem = failWith;
    if (problem != null) throw FormInboxException(problem, 'HTTP test');
    return csv;
  }
}
