import 'package:csv/csv.dart';
import 'package:drift/drift.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/investments/domain/investment.dart';
import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/features/backup/domain/backup_data.dart';
import 'package:hishab/features/categories/data/category_mapper.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/metals/domain/metals.dart';
import 'package:hishab/features/transactions/domain/transaction_type.dart';

/// Saving everything to a file and bringing it back, and exporting the
/// transactions as a spreadsheet.
class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// All accounts (archived ones too), categories, transactions and budgets.
  Future<BackupData> buildBackup(DateTime now) async {
    final accounts = await _db.accountsDao.getAll(includeArchived: true);
    final categories = await _db.categoriesDao.getAll(includeArchived: true);
    final transactions = await _db.transactionsDao.getAll();
    final budgets = await _db.budgetsDao.getAll();
    final debts = await _db.debtsDao.getAllDebts();
    final debtPayments = await _db.debtsDao.getAllPayments();
    final recurringRules = await _db.recurringDao.getAll();
    final goals = await _db.goalsDao.getAllGoals();
    final goalEntries = await _db.goalsDao.getAllEntries();
    final tags = await _db.tagsDao.getAll();
    final shoppingItems = await _db.bazarDao.getAllItems();
    final itemPrices = await _db.bazarDao.getAllPrices();
    final metalHoldings = await _db.metalsDao.getAll();
    final investments = await _db.investmentsDao.getAllInvestments();
    final investmentEntries = await _db.investmentsDao.getAllEntries();
    final challenges = await _db.challengesDao.getAll();
    return BackupData(
      exportedAt: now.toUtc(),
      accounts: [
        for (final a in accounts)
          BackupAccount(
            id: a.id,
            name: a.name,
            type: a.type,
            openingBalance: a.openingBalance,
            includeInTotal: a.includeInTotal,
            isArchived: a.isArchived,
            createdAt: a.createdAt.toUtc(),
            creditLimit: a.creditLimit,
            usdLimit: a.usdLimit,
            billDueDay: a.billDueDay,
          ),
      ],
      categories: [
        for (final c in categories)
          BackupCategory(
            id: c.id,
            name: c.name,
            type: c.type,
            parentId: c.parentId,
            icon: c.icon,
            color: c.color,
            isArchived: c.isArchived,
            sortOrder: c.sortOrder,
          ),
      ],
      transactions: [
        for (final t in transactions)
          BackupTransaction(
            id: t.id,
            type: t.type,
            amount: t.amount,
            accountId: t.accountId,
            toAccountId: t.toAccountId,
            categoryId: t.categoryId,
            date: t.date.toUtc(),
            note: t.note,
            isAdjustment: t.isAdjustment,
            usdAmount: t.usdAmount,
            tagId: t.tagId,
            feeling: t.feeling,
            createdAt: t.createdAt.toUtc(),
            updatedAt: t.updatedAt.toUtc(),
          ),
      ],
      budgets: [
        for (final b in budgets)
          BackupBudget(
            id: b.id,
            month: b.month,
            categoryId: b.categoryId,
            amount: b.amount,
          ),
      ],
      debts: [
        for (final d in debts)
          BackupDebt(
            id: d.id,
            person: d.person,
            direction: d.direction,
            amount: d.amount,
            openedOn: d.openedOn.toUtc(),
            dueOn: d.dueOn?.toUtc(),
            note: d.note,
            accountId: d.accountId,
            transactionId: d.transactionId,
            createdAt: d.createdAt.toUtc(),
          ),
      ],
      debtPayments: [
        for (final p in debtPayments)
          BackupDebtPayment(
            id: p.id,
            debtId: p.debtId,
            amount: p.amount,
            paidOn: p.paidOn.toUtc(),
            note: p.note,
            accountId: p.accountId,
            transactionId: p.transactionId,
            createdAt: p.createdAt.toUtc(),
          ),
      ],
      recurringRules: [
        for (final r in recurringRules)
          BackupRecurringRule(
            id: r.id,
            title: r.title,
            type: r.type,
            amount: r.amount,
            accountId: r.accountId,
            categoryId: r.categoryId,
            frequency: r.frequency,
            startDate: r.startDate.toUtc(),
            nextDue: r.nextDue.toUtc(),
            endDate: r.endDate?.toUtc(),
            autoAdd: r.autoAdd,
            remind: r.remind,
            isPaused: r.isPaused,
            createdAt: r.createdAt.toUtc(),
          ),
      ],
      shoppingItems: [
        for (final i in shoppingItems)
          BackupShoppingItem(
            id: i.id,
            name: i.name,
            quantity: i.quantity,
            price: i.price,
            isDone: i.isDone,
            createdAt: i.createdAt.toUtc(),
          ),
      ],
      metalHoldings: [
        for (final m in metalHoldings)
          BackupMetalHolding(
            id: m.id,
            metal: m.metal.name,
            name: m.name,
            milligrams: m.milligrams,
            purity: m.purity,
            cost: m.cost,
            createdAt: m.createdAt.toUtc(),
          ),
      ],
      itemPrices: [
        for (final p in itemPrices)
          BackupItemPrice(
            id: p.id,
            nameKey: p.nameKey,
            name: p.name,
            price: p.price,
            updatedAt: p.updatedAt.toUtc(),
          ),
      ],
      tags: [
        for (final t in tags)
          BackupTag(id: t.id, name: t.name, createdAt: t.createdAt.toUtc()),
      ],
      goals: [
        for (final g in goals)
          BackupGoal(
            id: g.id,
            name: g.name,
            target: g.target,
            targetDate: g.targetDate?.toUtc(),
            icon: g.icon,
            createdAt: g.createdAt.toUtc(),
          ),
      ],
      goalEntries: [
        for (final e in goalEntries)
          BackupGoalEntry(
            id: e.id,
            goalId: e.goalId,
            amount: e.amount,
            date: e.date.toUtc(),
            note: e.note,
            createdAt: e.createdAt.toUtc(),
          ),
      ],
      challenges: [
        for (final c in challenges)
          BackupChallenge(
            id: c.id,
            title: c.title,
            kind: c.kind.name,
            categoryId: c.categoryId,
            limit: c.limitAmount,
            startDate: c.startDate.toUtc(),
            endDate: c.endDate.toUtc(),
            createdAt: c.createdAt.toUtc(),
          ),
      ],
      investments: [
        for (final i in investments)
          BackupInvestment(
            id: i.id,
            name: i.name,
            note: i.note,
            startedOn: i.startedOn.toUtc(),
            currentValue: i.currentValue,
            isClosed: i.isClosed,
            createdAt: i.createdAt.toUtc(),
          ),
      ],
      investmentEntries: [
        for (final e in investmentEntries)
          BackupInvestmentEntry(
            id: e.id,
            investmentId: e.investmentId,
            kind: e.kind.name,
            amount: e.amount,
            date: e.date.toUtc(),
            note: e.note,
            accountId: e.accountId,
            transactionId: e.transactionId,
            createdAt: e.createdAt.toUtc(),
          ),
      ],
    );
  }

  /// Replaces everything in the app with [data]. All or nothing: if anything
  /// goes wrong the app keeps what it had.
  Future<void> restore(BackupData data) async {
    try {
      await _db.transaction(() async {
        await _deleteEverything();
        await _db.batch((batch) {
          batch.insertAll(_db.accounts, [
            for (final a in data.accounts)
              AccountsCompanion.insert(
                id: Value(a.id),
                name: a.name,
                type: a.type,
                openingBalance: Value(a.openingBalance),
                includeInTotal: Value(a.includeInTotal),
                isArchived: Value(a.isArchived),
                createdAt: Value(a.createdAt),
                creditLimit: Value(a.creditLimit),
                usdLimit: Value(a.usdLimit),
                billDueDay: Value(a.billDueDay),
              ),
          ]);
          // Parents first: a sub-category points at its parent. (The sort is
          // stable, so categories keep their order within a level.)
          batch.insertAll(_db.categories, [
            for (final c in data.categoriesParentsFirst)
              CategoriesCompanion.insert(
                id: Value(c.id),
                name: c.name,
                type: c.type,
                parentId: Value(c.parentId),
                icon: Value(c.icon),
                color: Value(c.color),
                isArchived: Value(c.isArchived),
                sortOrder: Value(c.sortOrder),
              ),
          ]);
          batch.insertAll(_db.recurringRules, [
            for (final r in data.recurringRules)
              RecurringRulesCompanion.insert(
                id: Value(r.id),
                title: r.title,
                type: r.type,
                amount: r.amount,
                accountId: r.accountId,
                categoryId: r.categoryId,
                frequency: r.frequency,
                startDate: r.startDate,
                nextDue: r.nextDue,
                endDate: Value(r.endDate),
                autoAdd: Value(r.autoAdd),
                remind: Value(r.remind),
                isPaused: Value(r.isPaused),
                createdAt: Value(r.createdAt),
              ),
          ]);
          batch.insertAll(_db.shoppingItems, [
            for (final i in data.shoppingItems)
              ShoppingItemsCompanion.insert(
                id: Value(i.id),
                name: i.name,
                quantity: Value(i.quantity),
                price: Value(i.price),
                isDone: Value(i.isDone),
                createdAt: Value(i.createdAt),
              ),
          ]);
          batch.insertAll(_db.metalHoldings, [
            for (final m in data.metalHoldings)
              MetalHoldingsCompanion.insert(
                id: Value(m.id),
                metal: Metal.values.byName(m.metal),
                name: m.name,
                milligrams: m.milligrams,
                purity: m.purity,
                cost: Value(m.cost),
                createdAt: Value(m.createdAt),
              ),
          ]);
          batch.insertAll(_db.itemPrices, [
            for (final p in data.itemPrices)
              ItemPricesCompanion.insert(
                id: Value(p.id),
                nameKey: p.nameKey,
                name: p.name,
                price: p.price,
                updatedAt: Value(p.updatedAt),
              ),
          ]);
          batch.insertAll(_db.tags, [
            for (final t in data.tags)
              TagsCompanion.insert(
                id: Value(t.id),
                name: t.name,
                createdAt: Value(t.createdAt),
              ),
          ]);
          batch.insertAll(_db.savingsGoals, [
            for (final g in data.goals)
              SavingsGoalsCompanion.insert(
                id: Value(g.id),
                name: g.name,
                target: g.target,
                targetDate: Value(g.targetDate),
                icon: Value(g.icon),
                createdAt: Value(g.createdAt),
              ),
          ]);
          batch.insertAll(_db.goalEntries, [
            for (final e in data.goalEntries)
              GoalEntriesCompanion.insert(
                id: Value(e.id),
                goalId: e.goalId,
                amount: e.amount,
                date: e.date,
                note: Value(e.note),
                createdAt: Value(e.createdAt),
              ),
          ]);
          batch.insertAll(_db.transactions, [
            for (final t in data.transactions)
              TransactionsCompanion.insert(
                id: Value(t.id),
                type: t.type,
                amount: t.amount,
                accountId: t.accountId,
                toAccountId: Value(t.toAccountId),
                categoryId: Value(t.categoryId),
                date: t.date,
                note: Value(t.note),
                isAdjustment: Value(t.isAdjustment),
                usdAmount: Value(t.usdAmount),
                tagId: Value(t.tagId),
                feeling: Value(t.feeling),
                createdAt: Value(t.createdAt),
                updatedAt: Value(t.updatedAt),
              ),
          ]);
          batch.insertAll(_db.debts, [
            for (final d in data.debts)
              DebtsCompanion.insert(
                id: Value(d.id),
                person: d.person,
                direction: d.direction,
                amount: d.amount,
                openedOn: d.openedOn,
                dueOn: Value(d.dueOn),
                note: Value(d.note),
                accountId: Value(d.accountId),
                transactionId: Value(d.transactionId),
                createdAt: Value(d.createdAt),
              ),
          ]);
          batch.insertAll(_db.debtPayments, [
            for (final p in data.debtPayments)
              DebtPaymentsCompanion.insert(
                id: Value(p.id),
                debtId: p.debtId,
                amount: p.amount,
                paidOn: p.paidOn,
                note: Value(p.note),
                accountId: Value(p.accountId),
                transactionId: Value(p.transactionId),
                createdAt: Value(p.createdAt),
              ),
          ]);
          batch.insertAll(_db.challenges, [
            for (final c in data.challenges)
              ChallengesCompanion.insert(
                id: Value(c.id),
                title: c.title,
                kind: ChallengeKind.values.byName(c.kind),
                categoryId: Value(c.categoryId),
                limitAmount: c.limit,
                startDate: c.startDate,
                endDate: c.endDate,
                createdAt: Value(c.createdAt),
              ),
          ]);
          batch.insertAll(_db.investments, [
            for (final i in data.investments)
              InvestmentsCompanion.insert(
                id: Value(i.id),
                name: i.name,
                note: Value(i.note),
                startedOn: i.startedOn,
                currentValue: Value(i.currentValue),
                isClosed: Value(i.isClosed),
                createdAt: Value(i.createdAt),
              ),
          ]);
          batch.insertAll(_db.investmentEntries, [
            for (final e in data.investmentEntries)
              InvestmentEntriesCompanion.insert(
                id: Value(e.id),
                investmentId: e.investmentId,
                kind: InvestmentEntryKind.values.byName(e.kind),
                amount: e.amount,
                date: e.date,
                note: Value(e.note),
                accountId: Value(e.accountId),
                transactionId: Value(e.transactionId),
                createdAt: Value(e.createdAt),
              ),
          ]);
          batch.insertAll(_db.budgets, [
            for (final b in data.budgets)
              BudgetsCompanion.insert(
                id: Value(b.id),
                month: b.month,
                amount: b.amount,
                categoryId: Value(b.categoryId),
              ),
          ]);
        });
      });
    } on ValidationException {
      rethrow;
    } on Object catch (error) {
      throw ValidationException(
        tr(
          'The backup could not be restored, and nothing was changed. '
          '{error}',
          {'error': error},
        ),
      );
    }
  }

  /// Rows that others point at go last: transactions and budgets first, then
  /// categories from the innermost out, then accounts.
  Future<void> _deleteEverything() async {
    await _db.delete(_db.challenges).go();
    await _db.delete(_db.investmentEntries).go();
    await _db.delete(_db.investments).go();
    await _db.delete(_db.metalHoldings).go();
    await _db.delete(_db.shoppingItems).go();
    await _db.delete(_db.itemPrices).go();
    await _db.delete(_db.goalEntries).go();
    await _db.delete(_db.savingsGoals).go();
    await _db.delete(_db.recurringRules).go();
    await _db.delete(_db.debtPayments).go();
    await _db.delete(_db.debts).go();
    await _db.delete(_db.budgets).go();
    await _db.delete(_db.transactions).go();
    await _db.delete(_db.tags).go();
    // A category that has others inside it cannot go before them, so remove
    // the ones nothing is inside, over and over, until none are left. Each
    // round takes one level off the bottom of the tree.
    var removed = 1;
    while (removed > 0) {
      removed = await _db.customUpdate(
        'DELETE FROM categories WHERE id NOT IN '
        '(SELECT parent_id FROM categories WHERE parent_id IS NOT NULL)',
        updates: {_db.categories},
        updateKind: UpdateKind.delete,
      );
    }
    await _db.delete(_db.accounts).go();
  }

  /// Every transaction as a spreadsheet, oldest first:
  /// `Date, Type, Amount, Account, To account, Category, Note, Correction`.
  /// The category of a sub-category is written with its whole path, like
  /// `Food > Restaurant > Dinner`. Amounts are
  /// plain taka (`1234.50`), the type is income, expense or transfer, and
  /// "Correction" says `yes` for a balance adjustment. The columns have the
  /// names the CSV import looks for, so the file can be imported again.
  Future<String> exportTransactionsCsv() async {
    final categories = await _db.categoriesDao.getAll(includeArchived: true);
    final byId = {for (final c in categories) c.id: c.toDomain()};
    final rows = await _db.transactionsDao.getAllWithDetails();
    // Written by hand: DateFormat needs locale data, and a sheet always wants
    // western digits.
    String two(int n) => n.toString().padLeft(2, '0');
    String csvDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)} '
        '${two(d.hour)}:${two(d.minute)}';

    String categoryPath(CategoryRow? category) {
      final domain = category == null ? null : byId[category.id];
      return domain == null
          ? ''
          : categoryPathLabel(domain, byId, separator: ' > ');
    }

    final table = <List<String>>[
      [
        'Date',
        'Type',
        'Amount',
        'Account',
        'To account',
        'Category',
        'Note',
        'Correction',
        'USD',
        'Tag',
      ],
      for (final row in rows)
        [
          csvDate(row.transaction.date.toLocal()),
          row.transaction.type.name,
          poishaToFixed(row.transaction.amount),
          row.account.name,
          row.transaction.type == TransactionType.transfer
              ? (row.toAccount?.name ?? '')
              : '',
          categoryPath(row.category),
          row.transaction.note,
          row.transaction.isAdjustment ? 'yes' : '',
          row.transaction.usdAmount == null
              ? ''
              : poishaToFixed(row.transaction.usdAmount!),
          row.tag?.name ?? '',
        ],
    ];
    // A byte order mark lets Excel and Sheets read Bangla text correctly.
    return Csv(addBom: true).encode(table);
  }
}
