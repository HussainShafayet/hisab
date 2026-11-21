import 'package:drift/drift.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/debts/data/debts_table.dart';

part 'debts_dao.g.dart';

/// A debt row with the sum of its payments and of its charges.
typedef DebtWithPaid = ({DebtRow debt, int paid, int charged});

@DriftAccessor(tables: [Debts, DebtPayments, DebtCharges])
class DebtsDao extends DatabaseAccessor<AppDatabase> with _$DebtsDaoMixin {
  DebtsDao(super.attachedDatabase);

  Stream<List<DebtWithPaid>> watchAllWithPaid() => _withPaid().watch();

  Future<List<DebtWithPaid>> getAllWithPaid() => _withPaid().get();

  Future<DebtWithPaid?> getWithPaid(int id) =>
      _withPaid(id: id).getSingleOrNull();

  Selectable<DebtWithPaid> _withPaid({int? id}) {
    return customSelect(
      'SELECT d.*, '
      '(SELECT COALESCE(SUM(p.amount), 0) FROM debt_payments p '
      'WHERE p.debt_id = d.id) AS paid, '
      '(SELECT COALESCE(SUM(c.amount), 0) FROM debt_charges c '
      'WHERE c.debt_id = d.id) AS charged '
      'FROM debts d '
      '${id == null ? '' : 'WHERE d.id = ? '}'
      'ORDER BY d.id DESC',
      variables: [if (id != null) Variable.withInt(id)],
      readsFrom: {debts, debtPayments, debtCharges},
    ).map(
      (row) => (
        debt: debts.map(row.data),
        paid: row.read<int>('paid'),
        charged: row.read<int>('charged'),
      ),
    );
  }

  /// The payments of one debt, newest first.
  Stream<List<DebtPaymentRow>> watchPayments(int debtId) =>
      (select(debtPayments)
            ..where((p) => p.debtId.equals(debtId))
            ..orderBy([
              (p) => OrderingTerm.desc(p.paidOn),
              (p) => OrderingTerm.desc(p.id),
            ]))
          .watch();

  Future<List<DebtPaymentRow>> getPayments(int debtId) =>
      (select(debtPayments)..where((p) => p.debtId.equals(debtId))).get();

  /// The charges of one loan, newest first.
  Stream<List<DebtChargeRow>> watchCharges(int debtId) =>
      (select(debtCharges)
            ..where((c) => c.debtId.equals(debtId))
            ..orderBy([
              (c) => OrderingTerm.desc(c.chargedOn),
              (c) => OrderingTerm.desc(c.id),
            ]))
          .watch();

  Future<List<DebtChargeRow>> getCharges(int debtId) =>
      (select(debtCharges)..where((c) => c.debtId.equals(debtId))).get();

  Future<List<DebtChargeRow>> getAllCharges() =>
      (select(debtCharges)..orderBy([(c) => OrderingTerm.asc(c.id)])).get();

  Future<DebtChargeRow?> getCharge(int id) =>
      (select(debtCharges)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<int> insertCharge(DebtChargesCompanion charge) =>
      into(debtCharges).insert(charge);

  Future<int> deleteCharge(int id) =>
      (delete(debtCharges)..where((c) => c.id.equals(id))).go();

  Future<List<DebtRow>> getAllDebts() =>
      (select(debts)..orderBy([(d) => OrderingTerm.asc(d.id)])).get();

  Future<List<DebtPaymentRow>> getAllPayments() =>
      (select(debtPayments)..orderBy([(p) => OrderingTerm.asc(p.id)])).get();

  Future<DebtRow?> getDebt(int id) =>
      (select(debts)..where((d) => d.id.equals(id))).getSingleOrNull();

  Future<DebtPaymentRow?> getPayment(int id) =>
      (select(debtPayments)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<int> insertDebt(DebtsCompanion debt) => into(debts).insert(debt);

  Future<bool> updateDebt(DebtRow debt) => update(debts).replace(debt);

  Future<int> insertPayment(DebtPaymentsCompanion payment) =>
      into(debtPayments).insert(payment);

  Future<int> deletePayment(int id) =>
      (delete(debtPayments)..where((p) => p.id.equals(id))).go();

  Future<int> deleteDebt(int id) =>
      (delete(debts)..where((d) => d.id.equals(id))).go();
}
