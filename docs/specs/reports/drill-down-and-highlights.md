# Reports: every number opens its entries, and highlights

Phone feedback (2026-11-05): "report page tao aro details ar UI valo hobe", "report e
ja ase oigulo click kore kono view or details e jawar kisu rakhte hobe?".

## Behaviour
- **Tap a number, see its entries** (`/entries`, a list on a screen of its own
  with a back button, the title of what was tapped and the filter already set to
  the period). It is the Transactions list, so search, the type chips, the facts
  line, edit, delete and select all work there.
  - *Income* and *Expense* in the summary card (`figure-Income`,
    `figure-Expense`; Income is not tappable while income is hidden).
  - A category of the pie (`legend-<id>`) or of the tree: the entries of the
    category and everything inside it. A group in the tree keeps its open/close
    on a tap and has a list button (`tree-open-<id>`); a leaf opens on a tap;
    the *Directly in {name}* row lists only what was put on the group itself.
  - An account in *By account* (`account-total-<id>`): what touched it.
  - A *Biggest spending day* tile (`highlight-day`): everything of that day.
  - A top expense still opens the entry itself.
- **Highlights card** (`report-highlights`), after the tree: the biggest spending
  day, days with no spending (*3 of 11*), the average expense, the busiest
  weekday, and a bar for each weekday (`weekday-bar-0` is Sunday). Balance fixes
  and transfers are not spending. Not shown when there was no expense.

## Rules
- `openEntries` (`transactions/presentation/open_entries.dart`) pushes
  `AppRoutes.entries` with a `FilteredEntriesArgs` (title + `TransactionFilter`);
  `TransactionsScreen(initialFilter:, title:)` starts with it. A custom range in
  the filter replaces the month switcher, and the range banner clears it.
- `ReportLinks` (`reports/presentation/report_links.dart`) builds the filters.
- `highlightsOf` (`reports/domain/report_highlights.dart`) counts the days of a
  period still going up to today.

## Tests
`test/features/reports/domain/report_highlights_test.dart`,
`test/features/reports/presentation/report_links_test.dart`.
