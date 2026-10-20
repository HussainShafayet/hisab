# Search filters

## Goal
Find a transaction by more than its words: how much it was, which trip it
belonged to, and how it felt afterwards.

## Behaviour
The Transactions tab already searches the note, the category and the amount,
and the **Filter** sheet narrows by type, category, account and a date range.
The sheet now also has:
- **Trip or event**: a drop-down of the tags (Trips & events), *Any trip or
  event* by default. It is left out while there are no tags.
- **Amount**: *From* and *To* boxes. Either may be empty; both ends count
  (50 to 500 includes 50 and 500). Amounts are typed as taka (`1,500.50`).
- **How it felt**: *Any*, *Needed*, *Wanted* or *Regret*.

The filter button shows how many options are set; the amount range counts as
one, whichever ends are filled. **Clear all** drops them with the others.

### Chips under the app bar
Each option that is set (type, category, account, amount range, trip or event,
feeling) shows as a chip under the month switcher, named by what it is (*Rickshaw*,
*From ৳500.00*, *৳100.00 – ৳900.00*, *Regret*). The cross on a chip takes off
just that option (`FilterChips`, `TransactionFilter.without`). The date range
keeps its own banner. The list and its totals at the top follow the filter.

### Saved filters
The sheet has **Save this filter**: it asks for a name (at most 30 letters)
and keeps the options of the sheet (not the dates or the search text) so they
can be used again, like *Regret over ৳500*. The saved ones show as chips under
*Saved filters* at the top of the sheet: a tap puts its options on the sheet
(then *Apply*), the cross deletes it. At least one option is needed to save
(*Pick at least one option to save.*). Saving under a name that exists (any
case) replaces it; at most 10 are kept and the oldest go first.

## Rules
- `TransactionFilter` has `minAmount` and `maxAmount` (poisha), `tagId` and
  `feeling`; `applyTransactionFilter` keeps what matches all of them together
  with the others. A transfer has an amount like any other, so the range
  applies to it; it has no tag and no feeling, so those options hide it.
- *Apply* refuses text that is not an amount (*Enter the amount as a number.*)
  and a *From* above *To* (*The smallest amount is above the largest.*): the
  sheet stays open with the message, which goes away when typing again.
- The search text is kept when the options change, and the new options are
  kept when the search text changes or the date range is cleared.
- Saved filters live in the app settings under `saved_filters` (JSON), so a
  backup holds them. A damaged entry is skipped when reading.
- The sheet does not wait for the tags to load; the drop-down appears when
  they are there.

## Tests
- `test/features/transactions/domain/transaction_filter_test.dart`
- `test/features/transactions/domain/saved_filter_test.dart`
- `test/features/transactions/presentation/filter_sheet_test.dart`
- `test/features/transactions/presentation/filter_chips_test.dart`
