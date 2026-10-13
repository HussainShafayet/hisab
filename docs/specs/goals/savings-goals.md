# Savings goals

## Goal
Let someone save up for something (a laptop, a trip, Eid) in small steps and see
how far they have come. The money is set aside in the app only: no account
changes, so balances and reports are not touched.

## Behaviour
- **More > Savings goals** lists the goals, oldest first, under a summary of what
  is put aside across all of them. Empty, it invites the first goal.
- A goal card shows an icon, the name, a progress bar, `saved of target`, the
  percent, and one line on what to do next (`goalHint`):
  - reached: *Goal reached*;
  - no day: *X to go*;
  - day under 31 days away: *X to go by 12 Dec 2026*;
  - day further away: *Put aside X a month to reach it by 12 Dec 2026*;
  - day passed: *Past 12 Dec 2026 - X to go*, in red.
- **New / edit goal**: name (required, up to 60), target (above zero), an
  optional day to reach it by (cleared with the x), an icon out of 12.
- **Goal screen**: saved, target, percent, the hint, about how much a week, the
  days left, *Put money in* and *Take out* (a dialog: amount, note, day up to
  today), and the history of entries, newest first, each removable. The menu
  edits or deletes the goal.
- Deleting a goal asks first and removes its entries; accounts are not touched.

## Rules
- `saved` = sum of the entries (above zero put in, below zero taken out);
  `left = max(0, target - saved)`; reached when `saved >= target`.
- Taking out more than `saved` is refused (*Only X is saved in this goal.*);
  so is removing an entry when money was taken out after it and would then
  exceed what is left. An entry is never zero.
- `perMonth = ceil(left / max(1, ceil(daysLeft / 30)))`, `perWeek` likewise with
  7. Both are null without a day, once reached, and from the day itself on.
- Days are dates (local midnight). `savings_goals.target > 0` and
  `goal_entries.amount <> 0` are checked in the database too.
- Schema version 8 adds `savings_goals` and `goal_entries` (entries go with their
  goal). Backup format 6 saves both; an older file reads as having none.

## Tests
- `test/features/goals/domain/goal_test.dart`
- `test/features/goals/data/goals_repository_test.dart` (rules, deleting,
  watching, backup)
- `test/features/goals/presentation/goals_screen_test.dart` (list, form, goal
  screen)
- `test/core/database/migration_test.dart` (version 7 to 8)
