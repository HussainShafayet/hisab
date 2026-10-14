/// Name of the category used for balance-adjustment transactions. It is
/// created on first use, once for income and once for expense. The lookup is
/// by name, so a renamed category is simply not found and a new one is made.
const balanceAdjustmentCategoryName = 'Balance adjustment';

/// Note saved on balance-adjustment transactions.
const balanceAdjustmentNote = 'Balance adjustment';

/// Expense category for transfer fees. It matches a default category, and is
/// created on first use if the user removed or renamed it.
const transferFeeCategoryName = 'Fees & charges';

/// Note saved on the expense that records a transfer fee.
const transferFeeNote = 'Transfer fee';

/// The category of the transactions that move an account's balance for a loan
/// (money lent, borrowed or paid back). They are corrections as far as income
/// and expense go: lending is not spending.
const loanCategoryName = 'Loans';

/// The category of the transactions that move an account's balance for money
/// put into an investment or taken back from it. They are corrections as far
/// as income and expense go: investing is not spending.
const investmentCategoryName = 'Investments';

/// The income category of the profit received from an investment. Unlike the
/// money put in and taken back, profit counts as income.
const investmentProfitCategoryName = 'Investment profit';
