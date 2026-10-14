# Below-zero warning

## Goal
An account that holds less than nothing means an entry is missing or wrong
(a spend put on the wrong wallet, money received but not written down). The
app says so instead of showing a quiet minus sign.

## Behaviour
- Home: a card under the total ("1 account is below zero" / "{count} accounts
  are below zero") lists up to three accounts with what each holds, the deepest
  first. Tapping it opens the accounts. It is not shown when nothing is below
  zero, and it goes away on its own once the money is put back.
- The account card (accounts screen, Home strip, pickers) says "Below zero"
  with an amber warning mark and an amber amount instead of "Balance".
- The preview in the add form already warns before saving (see
  [wallet cards](wallet-cards.md)). Saving is still allowed: a bank overdraft
  is real.

## Rules
- `isOverdrawn(item)` is true when the balance is below zero, the account is
  not a credit card and is not archived. A credit card owes by design (its own
  warning is the limit, see [credit cards](credit-cards.md)); an archived
  account is no longer in use.
- An account left out of the total with "Not in total" still counts: it can be
  below zero just the same.
- `overdrawnAccounts` sorts by balance, lowest first.

## Tests
- `test/features/accounts/domain/overdrawn_test.dart`
- `test/features/accounts/presentation/overdrawn_card_test.dart`
