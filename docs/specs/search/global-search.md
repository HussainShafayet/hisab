# Search everything

From the earlier list of ideas ("global search"), built when the user asked for the
rest to be done.

## Behaviour
- A search button on Home (`home-search`) opens one box (`global-search`) that looks
  through the **transactions** (note, category, amount), **accounts** (name),
  **categories** (name and where they sit) and **loans** (person, note). Fewer than
  two letters finds nothing and the screen explains what it can do (`search-hint`).
- The newest 20 transactions are listed; when more match, *See all N in the list*
  (`search-more`) opens them in the Transactions list with the search already set.
- A tap opens what was found: the transaction to edit, the account's page, the
  category's entries, the loan.
- Balance fixes never match; nothing found says *Nothing matches "..."*
  (`search-empty`).

## Rules
`searchAll` (`search/domain/search_results.dart`) is pure; transactions are matched
with the same filter as the Transactions list, so the same words find the same
things.

## Tests
`test/features/search/search_results_test.dart`,
`test/features/search/global_search_ui_test.dart`.
