# The year view of the reports

## Goal
With two years of entries, the month-by-month Reports screen is not enough:
the question is how a whole year went, which month was heavy, and whether it
is better than last year.

## Behaviour
- Under the app bar of Reports is a **Month | Year** switch (hidden while a
  custom date range is chosen, as the month arrows are). *Year* shows
  `‹ 2026 ›`: the arrows go to the year before and after, and not beyond this
  year.
- The report is for the whole calendar year (`yearRange`, 1 January to 1
  January). Everything of the month view is there (summary, the pie, the
  category tree, the accounts, the biggest expenses), for the year, and:
  - *Compared with 2025*: a whole calendar year is compared with the year
    before (`previousPeriod`), even after a leap year;
  - the daily average counts the days of the year so far;
  - the bar chart of income against expense has the **twelve months** of the
    year, not the last six;
  - **Month by month**: for each month up to today (all twelve for a past
    year) a row with the income and the expense as two thin bars (scaled to
    the biggest month of the year) and what was left (green with a plus, red
    with a minus, a dash when nothing was written). A tap on a month opens it
    in the month view.
  - under it: *Average per month: income X, expense Y*, *Most spent:
    October, ৳10,000.00*, *Most kept: ...* and *Averages are over the N
    months with entries.*
- The averages count the months that have any income or expense and have
  started (`yearFacts`): a year in which the person began in October is
  averaged over those months, not over twelve. *Most kept* is only there when
  a month ended above zero.
- Transfers and balance corrections are not counted, as everywhere.

## Rules
- The twelve months come from `monthlyTotals(December, count: 12)` through
  `yearMonthsProvider`, which is calculated again after any change to the data.

## Tests
- `test/core/utils/dates_test.dart` (*yearRange*, *previousPeriod of a year*)
- `test/features/reports/domain/year_facts_test.dart`
- `test/features/reports/presentation/year_view_test.dart`
