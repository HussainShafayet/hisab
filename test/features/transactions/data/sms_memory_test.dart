import 'package:flutter_test/flutter_test.dart';
import 'package:hishab/features/transactions/data/sms_memory.dart';

import '../../../helpers/test_database.dart';

void main() {
  test('remembers the account chosen for a kind of SMS', () async {
    final db = createTestDatabase();
    addTearDown(db.close);

    expect(await readSmsAccounts(db), isEmpty);
    await rememberSmsAccount(db, 'id-trxid', 7);
    await rememberSmsAccount(db, 'ac1234', 9);
    await rememberSmsAccount(db, 'id-trxid', 8);

    expect(await readSmsAccounts(db), {'id-trxid': 8, 'ac1234': 9});
  });
}
