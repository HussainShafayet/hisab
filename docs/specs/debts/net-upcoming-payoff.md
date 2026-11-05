# Loans: where I stand, what is coming up, search, sort and paying in parts

Phone feedback (2026-11-05): "loan, liability same improvement er aro jayga ache".

## Behaviour
- **Net line** under the totals (`loan-net`): *You will get ৳3,000.00 more than
  you give.*, *You will give ৳X more than you get.* or *You are even.* Credit
  card bills count as money to give (`netPosition`).
- **Coming up** (`loan-upcoming`): the next three open loans due within 30 days,
  soonest first, each with the person, what is left and *Today* / *Tomorrow* /
  *in N days*; a tap opens the loan (`upcoming-<id>`). Late loans are not here
  (the summary and the lists show them). Nothing is shown when none is due.
  (`upcomingDues`)
- **Search** (`loan-search-toggle`, `loan-search`) in the app bar filters the
  three tabs by the person's name or the note; closing it clears it.
- **Sort** (`loan-sort`): *Late and due first* (the usual), *Biggest left first*,
  *Newest first*. Paid loans always come last. (`searchAndSort`, `LoanSort`)
- **Pay it off in parts** (`payoff-card`) on a loan that is not paid: choose 3, 6
  or 12 months (`payoff-3/6/12`) and it says *৳200.00 a month for 6 months.*
  (with *, the last one ৳X* when the last part is smaller) and the month it ends
  in. For money lent the card says *Get it back in parts*. (`payoffPlan`)

## Tests
`test/features/debts/domain/loan_insights_test.dart`,
`test/features/debts/presentation/loan_insights_ui_test.dart`.
