# Data check

## Goal
After an import, or after a year of entering, some entries are wrong without
anyone having noticed: one entered twice, a wrong year, an extra zero. The
screen finds the likely ones and leaves the choice to the person.

## Behaviour
- **More > Setup > Data check** (`/more/data-check`, a **?** button for the
  guide). It looks at every entry, and again after any change. Nothing is
  changed unless the person says so. When there is nothing to see: *Everything
  looks fine*. Otherwise it says *N things to look at* and shows a card for each
  kind that has something:
  1. **Entered twice?** Entries on the same day (any hour) with the same kind,
     amount, account(s) and note (case and spaces ignored), from ৳500
     (`duplicateMinAmount`): rickshaw twice for ৳20 is a day, not a mistake.
     Each group says *N times, amount, date*, lists its entries (a tap opens
     one to edit) and has **Delete the extra N**: after a question, the first
     one entered stays, the others are deleted, and *Undo* stays for 8 seconds.
  2. **Dated in the future**: after today (any hour of today is fine), the
     soonest first.
  3. **Far above the usual**: an expense of at least 10 times the usual
     (median) expense of its category (`largeFactor`), at least ৳1,000
     (`largeMinAmount`), in a category with at least 8 entries
     (`largeMinEntries`), biggest first. A slip of a zero.
  4. **In "Other"**: how many entries and how much sit in *Other* and *Other
     income*, with the biggest 20, and the hint that Select several (in
     Transactions) moves many at once.
  5. **Categories that look alike**: two active categories of one type with
     names where one holds the other once the plural is taken off (*Utility*
     and *Utilities*; `similarCategory`). Not listed: the same name under two
     groups (*Gifts* of the wife and of the children, on purpose), a group and
     what is inside it, archived categories, income against expense. A tap
     opens Categories, where *Merge into…* does it.
- At most 20 entries are listed per kind (`maxListed`).
- A balance correction is not an entry of the person's and is never listed.

## Rules
- The check is pure (`checkData`, `lib/features/data_check/domain`); the
  provider loads the entries once (`TransactionsRepository.getBetween`) and the
  categories in use.

## Tests
- `test/features/data_check/domain/data_check_test.dart`
- `test/features/data_check/presentation/data_check_ui_test.dart`
- `test/features/backup/domain/import_tools_test.dart` (the plural in
  `similarCategory`)
- `test/features/help/domain/guide_test.dart` (the guide has a topic for it)
