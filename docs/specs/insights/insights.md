# Insights, the new Home, budget pace and reports

## Goal
Home says how things stand and what to look at in a few lines; reports and the
budget answer "where did it go" and "will it last".

## Home
Top to bottom: what is due now (recurring), the **total balance** on a gradient
card, the **wallet strip** (account cards that scroll sideways, tap to edit),
this month's income and expense, the monthly budget ring, today and this week,
**Insights**, top spending, recent transactions.

## Insights
At most four short sentences about this month so far, warnings first, then good
news, then plain facts (`buildInsights`):
- *Spending vs last month*: this month's spending against the same days of last
  month (day 1 to today's day number; a shorter last month counts whole). A
  change of 10% or more is mentioned ("You spent 50% more ..." as a warning, "...
  less ..." as good news).
- *Budget pace*: from day 3, with an overall budget and some spending: spending
  so far times the days of the month, divided by the day number. Above the
  limit is a warning, below it is good news.
- *A category that jumped*: the category with the biggest rise over the same
  days of last month, if it is at least ৳500 and a quarter more.
- *Loans*: how many are overdue (warning); what people owe you; what you owe.
- *Biggest slice*: a category that is 35% or more of the spending.
- *Recurring*: the next active recurring item due within 7 days.
Nothing is shown when there is nothing to say. They update when data, loans or
recurring items change.

## Budget
- The tab icon is a pie chart; the overall budget card has one too.
- **Pace** line on the overall budget of the current month, from day 3: "On
  track for the month", "Spending faster than the month goes" (amber) or
  "Spending slower ...", comparing the share of the budget used with the share
  of the month gone, 10 percentage points apart (`budgetPace`).

## Reports
- The summary also says "Kept N% of income" (or "Spent N% more than income")
  and the average spending per day of the period.
- *Spending by category* can be switched to *Income by category*.
- **By account**: income and expense of each account in the period; transfers
  and corrections are left out like everywhere.

## Tests
- `test/features/insights/domain/insights_test.dart`
- `test/features/insights/data/insights_repository_test.dart`
- `test/features/insights/presentation/insights_card_test.dart`
- `test/features/budget/domain/budget_pace_test.dart`
- `test/features/reports/data/reports_extras_test.dart`
