# Wallet cards and the balance preview

## Goal
When money is entered it is clear which wallet it moves, how much is in it,
and how much will be left.

## Behaviour
- `AccountCard`: a colored card (gradient by kind: cash green, mobile banking
  pink, bank blue, card purple; archived accounts grey) with the name, kind,
  balance and, when asked, an "After this" line.
- "After this" is the balance once the transaction is saved: income adds,
  expense subtracts, a transfer subtracts from "From" (fee included) and adds
  to "To". Nothing is shown until an amount is entered. It follows the
  keyboard, the calculator and the fee as they change.
- If the result is below zero the amount is amber with a warning icon. Saving
  is still allowed.
- Editing a transaction takes the old one back first, so the balance is not
  counted twice; moving it to another account is handled the same way.
- The account sheet lists the cards with their balances. In a transfer the
  account on the other side is shown but cannot be chosen. Archived accounts
  are not offered (except the one already used by the transaction).
- Balances are live: after "Save & new" the card shows the new balance.
- The kind ("Cash", "Bank") is written under the name unless the name already
  says it, so an account called "Cash" does not read "Cash / Cash".
- The same card is used on the [accounts screen](accounts-screen.md), with a
  menu in place of the check.

## Rules
- `TransactionEffect.changeFor(account)` and `projectedBalance` are pure and
  hold the arithmetic.
- Balances come from `accountsProvider(true)`.

## Tests
- `test/features/transactions/domain/balance_preview_test.dart`
- `test/features/accounts/presentation/account_card_test.dart`
- `test/features/transactions/presentation/transaction_form_screen_test.dart`
  (groups "choosing an account", "the balance", "transfer")
