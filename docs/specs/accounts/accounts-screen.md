# Accounts screen

## Goal
See every wallet and the total at a glance, and manage them without hunting
for icons.

## Behaviour
- A total card on top: the total balance (large), how many accounts are
  included, and, when more than one kind of account is counted, how much is
  in each kind (cash, mobile banking, bank, card).
- A **Show archived** chip under it (words, not an eye icon). Archived accounts
  are hidden, not deleted, so old transactions keep their account; the chip
  brings them back, greyed, so they can be restored.
- One [wallet card](wallet-cards.md) per account. Tap a card to edit it. The
  three dots on a card open Edit, Adjust balance, and Archive (Restore for an
  archived one). Archiving asks first and can be undone from the snack bar.
- "Add account" button (always visible). With no accounts: "No accounts yet"
  and an Add account button; the Show archived chip stays, so archived
  accounts can still be reached.

## Rules
- The total and the per-kind amounts count the same accounts: active ones that
  are not switched off with "Include in total balance". They add up to the
  total (`totalByAccountType` and `calculateTotalBalance`).
- A negative total is shown amber, not hidden.
- A card does not repeat the kind under a name that already says it (an
  account called "Cash" shows no "Cash" line).

## Tests
- `test/features/accounts/presentation/accounts_screen_test.dart`
- `test/features/accounts/presentation/account_card_test.dart`
- `test/features/accounts/domain/account_balance_test.dart`
  (`totalByAccountType`)
- `test/core/widgets/show_archived_chip_test.dart`
- `test/features/transactions/presentation/small_screen_test.dart` - the screen
  with every kind of account and huge balances at 360 dp, text x1.0 and x1.5.
