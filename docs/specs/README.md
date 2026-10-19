# Specs

What each part of Hishab is supposed to do, one folder per feature, mirroring
`lib/features/`. A spec says what the user sees and what the rules are, and
lists the tests that check it. Change the spec, and the matching topic of the
[user guide](help/user-guide.md), in the same commit as the behaviour.

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
| [core](core/) | [Messages and errors](core/messages-and-errors.md) | 19 |
| [debts](debts/) | [Loans (dhar / baki)](debts/loans.md) | 10b, 11 |
| [debts](debts/) | [Split a bill](debts/split-bill.md) | 17 |
| [recurring](recurring/) | [Recurring transactions and reminders](recurring/recurring.md) | 10c |
| [insights](insights/) | [Insights, the new Home, budget pace and reports](insights/insights.md) | 10d |
| [accounts](accounts/) | [Credit cards](accounts/credit-cards.md) | 11 |
| [goals](goals/) | [Savings goals](goals/savings-goals.md) | 13 |
| [budget](budget/) | [Safe to spend today](budget/safe-to-spend.md) | 14 |
| [tags](tags/) | [Trips and events](tags/trips-and-events.md) | 15 |
| [bazar](bazar/) | [Bazar list](bazar/bazar-list.md) | 16 |
| [zakat](zakat/) | [Zakat](zakat/zakat.md) | 18 |
| [accounts](accounts/) | [Below-zero warning](accounts/negative-balance.md) | 20 |
| [categories](categories/) | [Everyday Bangladesh categories](categories/bangladesh-categories.md) | 21 |
| [core](core/) | [Fun mode: Takka, jokes, motion](core/fun-mode.md) | 21 |
| [reports](reports/) | [Where the money went (category tree)](reports/category-tree.md) | 21 |
| [investments](investments/) | [Business investments](investments/investments.md) | 26 |
| [transactions](transactions/) | [Quick type](transactions/quick-type.md) | 22 |
| [dashboard](dashboard/) | [Loans up front (Home shortcuts)](dashboard/home-shortcuts.md) | 22 |
| [metals](metals/) | [Gold & silver](metals/gold-and-silver.md) | 23 |
| [goals](goals/) | [Eid and festival funds](goals/festival-funds.md) | 24 |
| [transactions](transactions/) | [How it felt, and the regret meter](transactions/feelings-and-regret.md) | 25 |
| [core](core/) | [Streaks and badges](core/badges-and-streaks.md) | 26 |
| [budget](budget/) | [Can I afford it?](budget/can-i-afford-it.md) | 27 |
| [core](core/) | [Month wrapped](core/month-wrapped.md) | 27 |
| [reminders](reminders/) | [Funny alerts](reminders/funny-alerts.md) | 28 |
| [help](help/) | [User guide](help/user-guide.md) | 29 |
| [transactions](transactions/) | [Add several](transactions/add-several.md) | 28 |
| [notifications](notifications/) | [Notification history](notifications/notification-history.md) | 30 |

Specs for the earlier milestones (accounts, categories, transactions, budget,
dashboard, reports, backup) have not been written down yet.

## Layout of a spec

1. **Goal** - why it exists, in a sentence or two.
2. **Behaviour** - what the user sees and does.
3. **Rules** - the exact rules, edge cases included.
4. **Tests** - the test files that cover it. Tests are written together with
   the code; running the whole suite is done on request.
