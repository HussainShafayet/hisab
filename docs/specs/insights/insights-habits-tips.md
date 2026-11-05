# More insights, habits and a tip of the day

Phone feedback (2026-11-05): "habits, tips and fun aro improve koro. insights aro
improve koro".

## Behaviour
- **More > For fun > Insights & habits** (`/more/insights`): a *Tip of the day*
  (`tip-card`, *Another tip* shows the next), *This month* with every insight
  (up to 12; `insights-all`), and *Your habits*.
- The card on Home keeps the first four and now has *See all*
  (`insights-see-all`). **Every insight that leads somewhere is tappable**: spending,
  category, top category, no-spend days, weekday, savings and regret open
  Reports; the budget pace opens Budget; a recurring item opens Recurring; a
  loan opens Loans; the biggest expense opens that entry.
- **New insights** (on top of spending up/down, budget pace, category jump, top
  category and recurring soon; warnings first, then good news, then facts):
  - *noSpendDays*: 3 or more days with no spending, from the 5th of the month.
  - *busyWeekday*: from the 14th, with ৳2,000 spent, one weekday takes 30% or more.
  - *biggestExpense*: the biggest expense is ৳1,000 or more and a fifth of the month.
  - *savingsKept* (kept 20% or more of the income) and *spentMoreThanEarned*,
    from the 7th, with an income.
  - *smallSpends*: 8 or more expenses under ৳100 adding up to ৳500 or more.
  - *regretShare*: 15% or more of the spending is marked Regret.
  - *loanToGet* / *loanToPay*: the next loan falls due within 7 days.
- **Your habits** (`habits-card`): a category spent on 8 times or more in the
  last 30 days, the costliest first (three at most), with the total and *about
  ৳X a month*; a tap lists those entries. Empty: *No habit yet...* (`no-habits`).
  (`habitsOf`)
- **Tips**: 20 short pieces of advice, one a day by the day of the year
  (`tipOfTheDay`), in English and Bangla.

## Tests
`test/features/insights/domain/insights_more_test.dart`, `habits_test.dart`,
`test/features/insights/presentation/insights_screen_test.dart`,
`money_tips_test.dart`.
