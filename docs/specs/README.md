# Specs

What each part of Hishab is supposed to do, one folder per feature, mirroring
`lib/features/`. A spec says what the user sees and what the rules are, and
lists the tests that check it. Change the spec in the same commit as the
behaviour.

| Folder | Spec | Milestone |
|---|---|---|
| [categories](categories/) | [Categories inside categories](categories/multi-level-categories.md) | 8 |
| [categories](categories/) | [Category picker](categories/category-picker.md) | 8 |
| [transactions](transactions/) | [Add / edit transaction form](transactions/entry-form.md) | 8 |
| [accounts](accounts/) | [Wallet cards and the balance preview](accounts/wallet-cards.md) | 8 |
| [accounts](accounts/) | [Accounts screen](accounts/accounts-screen.md) | 9 |
| [accounts](accounts/) | [Add / edit account](accounts/account-form.md) | 9 |
| [categories](categories/) | [Categories screen](categories/categories-screen.md) | 9 |
| [categories](categories/) | [Add / edit category](categories/category-form.md) | 9 |
| [settings](settings/) | [Settings](settings/settings.md) | 10a |
| [core](core/) | [Bangla UI](core/bangla-ui.md) | 10a |
| [debts](debts/) | [Loans (dhar / baki)](debts/loans.md) | 10b |
| [recurring](recurring/) | [Recurring transactions and reminders](recurring/recurring.md) | 10c |

Specs for the earlier milestones (accounts, categories, transactions, budget,
dashboard, reports, backup) have not been written down yet.

## Layout of a spec

1. **Goal** - why it exists, in a sentence or two.
2. **Behaviour** - what the user sees and does.
3. **Rules** - the exact rules, edge cases included.
4. **Tests** - the test files that cover it. Tests are written together with
   the code; running the whole suite is done on request.
