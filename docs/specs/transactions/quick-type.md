# Quick type

## Goal
Add an everyday entry in one line (`rickshaw 50`, `bazar 450 bkash`,
`+salary 30k`) instead of walking through every field.

## Behaviour
- At the top of **Add transaction** (not when editing, not when paying a card
  bill) there is a line with a bolt icon: *Type it in one line: rickshaw 50*.
- While typing, small pills show what was understood: income (only when it is
  one), the amount (or *No amount yet*), the category, the account.
- The tick (or the keyboard's Done) fills the form: type, amount, note,
  category, account. What was not understood stays as it was. A notice says
  *Filled in. Check it and save.* The entry is never saved without the Save
  button.

## Rules
- Pure parser: `parseQuickEntry` in `transactions/domain/quick_entry.dart`.
- **Amount** is the last number in the line. `2k`, `1.5k`, `3 hajar`,
  `2 lakh`, `450 tk`, `450 taka`, `৳1,250` and Bengali digits (`৫০`) all work.
- **Type**: an expense, an income when the line starts with `+` or has a word
  like salary, bonus, income, received, profit, refund, cashback, পেলাম.
- **Account**: a word of at least 3 letters equal to a word of an active
  account's name (English or Bangla), or at least 4 letters starting one. The
  word is left out of the note.
- **Category** (active, of the line's type), first hit wins: the whole text is
  a category name; a word is a category name; a word (4+ letters) is a word of
  a category name (shortest name wins: "rickshaw" -> "Bus & rickshaw"); the
  everyday words table of `suggestParent` ("ilish" -> Fish, the nearest
  existing parent when the exact one is gone).
- **Note** is what is left, first letter capitalised.
- Works offline, nothing is downloaded or sent.

## Tests
- `test/features/transactions/domain/quick_entry_test.dart`
- `test/features/transactions/presentation/quick_type_test.dart`
