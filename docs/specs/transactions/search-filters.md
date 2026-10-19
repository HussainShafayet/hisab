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
- The sheet does not wait for the tags to load; the drop-down appears when
  they are there.

## Tests
- `test/features/transactions/domain/transaction_filter_test.dart`
- `test/features/transactions/presentation/filter_sheet_test.dart`
