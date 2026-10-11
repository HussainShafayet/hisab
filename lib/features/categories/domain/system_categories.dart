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
