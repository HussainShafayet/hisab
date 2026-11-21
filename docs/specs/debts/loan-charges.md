# Late fees and charges on a loan I took

## Goal
When money I took (a liability) gets a late fee, interest or another charge,
the app can say so: what I owe goes up by that amount, and the cost is my
expense. Editing the amount of the loan is not the same: that would move the
account balance, and it would not be an expense.

## Behaviour
- **Where**: the loan screen (borrowed loans only) has **Add a late fee or
  charge** (`add-charge`), also in the long-press sheet on the list
  (`loan-action-charge`). A paid loan can get a charge too; it is open again.
  Loans I gave have no such button.
- **The dialog** (`LoanChargeDialog`): what it was for (chips `charge-kind-*`:
  Late fee, Interest, Service charge, Another charge), amount (above zero),
  date (not after today), note, and **Count it as my expense** (on by default;
  only shown when there is an account). When on, a *Written on* row shows the
  account (the loan's own account, else the default account, else the first
  one) and a tap picks another.
- **What is owed**: `DebtItem.total = amount + charged`; `remaining = total -
  paid`; progress is paid / total. The loan screen says *Includes {amount} of
  charges*, the list and the "Paid x of y" lines use the total. The amount
  borrowed is not changed, so the account change the loan made stays as it was.
- **As an expense**: an expense in the fee category of the kind (Late fee, Loan
  interest, Bank charge, Other charge; found or made inside *Fees & charges*)
  on the chosen account, dated the charge's day, with the note (or "Late fee
  on loan from Rahim"). No money moves, so a correction of the same amount
  (`is_adjustment`, in *Loans*) cancels it on that account, the way a bill paid
  for me is kept. Reports and budgets count the expense, not the correction.
- **The list on the loan screen**: *Charges*, newest first, each with kind, date
  and note; the bin asks "Delete this charge?" and takes the charge and both
  entries away. It is refused when the payments made are more than would then be
  owed (*The payments made already cover this charge.*).
- **Rules**: deleting a loan deletes its charges and their entries. A loan with
  charges cannot become a loan I gave; its amount can go down only while amount
  + charges still covers what was paid. Set-off, totals, reminders and people
  totals use what is left, so they include charges.

## A transfer charge when paying back
Paying back money I took by bank or bKash often costs a charge. **Add a payment**
(`payment-fee`) and **All paid** (`pay-all-fee`) have a *Transfer charge* field,
shown for a loan I took when an account is chosen (empty = none).
- It is a real expense on that account (not a correction): the balance goes down
  by the payment and the charge, and the "After this" line counts both. Category:
  *bKash charge* or *Nagad charge* when the account's name has bKash or Nagad,
  else *Bank charge* (found or made inside *Fees & charges*); note "Transfer
  charge paying Rahim"; dated the payment's day.
- It does not count against the loan: only the amount reduces what is left.
- Stored as `debt_payments.fee_transaction_id` (no foreign key: the entry may be
  deleted by hand). Taking the payment back (Delete, Undo of All paid) or
  deleting the loan deletes the entry too. Backup: `feeTransactionId` on a payment.
- Refused: a charge without an account, on a loan I gave, or below zero.
  Nothing is saved when the payment itself is refused.

## Data
- Table `debt_charges` and `debt_payments.fee_transaction_id` (schema 21): `debt_id` (cascade), `amount` (> 0),
  `charged_on`, `kind` (`lateFee`, `interest`, `serviceCharge`, `other`),
  `note`, `transaction_id` (the correction) and `expense_id`, both set null.
- Backup format 14: `debtCharges`. An older file has none and is read as such.

## Not done
- Charges on a loan I gave (interest I charge someone) are not handled.
- The expense and the charge are linked only through the charge's two ids; an
  expense deleted by hand stays deleted, and the charge stays.

## Tests
- `test/features/debts/data/loan_charges_test.dart`
- `test/features/debts/data/loan_payment_fee_test.dart`
- `test/features/debts/data/loan_charges_backup_test.dart`
- `test/features/debts/presentation/loan_charges_ui_test.dart`
- `test/core/database/migration_test.dart` (version 20 to 21)
