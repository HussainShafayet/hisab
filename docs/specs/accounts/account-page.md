# Account page and the month on each card

Phone feedback (2026-11-05): "accounts route ta aro improve kora jay and UI also".

## Behaviour
- **A month line under every wallet card**: *In ৳50,000.00 · Out ৳1,250.00 · 3
  entries this month*, or *Nothing this month*. Balances hidden in Settings hide
  the amounts here too. (`ActivityLine`, `monthActivityProvider`.)
- **A share bar in the total card** (`share-bar`): one slice for each kind of
  account that holds something, as wide as its share (kinds with nothing or in
  debt are left out; hidden with the balances).
- **Tapping a card opens the account's page** (`/more/accounts/<id>/details`).
  Editing, adjusting and archiving stay in the card's menu, and the pencil on
  the page (`detail-edit`) edits.
  - The card (a credit card also shows its bill, limit and dollars).
  - **Add to this account**: *Expense*, *Income*, *Transfer* (`detail-expense`,
    `detail-income`, `detail-transfer`) open the add form already on this account
    and type (`/add?account=<id>&type=<name>`); *Adjust balance* (`detail-adjust`).
    Not for an archived account.
  - A **month switcher** and a card with *In*, *Out* and *Net* of that month
    (`detail-summary`).
  - Every entry that touched the account that month, by day, as in the
    Transactions tab; a tap opens it. *Nothing on this account in {month}* when
    there is none.

## Rules
- `activityByAccount` (`account_activity.dart`): income is in, spending is out; a
  transfer is out of the sender and in to the receiver (its fee is a separate
  expense on the sender); balance fixes are left out, as in every other total.
  `touching` picks the entries a given account sent, received or holds.
- The form takes `account` and `type` query parameters only when adding a new
  transaction that is not a card bill; an account that cannot be used (archived
  or gone) is ignored.

## Tests
`test/features/accounts/domain/account_activity_test.dart`,
`test/features/accounts/presentation/account_detail_test.dart`.
