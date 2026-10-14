# Streaks and badges

## Goal
A little game on top of the book-keeping: write something every day, have days
with no spending, and win badges, so writing things down feels good.

## Behaviour
- **Home** (Fun mode only), under Takka: a flame, *N days in a row* (or *Write an
  entry today to start a streak!*), *N spend-free days this month* when there are
  any, and *N of 11 badges*. A tap opens **Badges** (also under More).
- **Badges** shows the count, the streak now and the best one, and all the badges
  with how to win each; the ones not won are grey with a lock.
- Badges: First step, Three in a row, A week of hishab, Hishab master (3, 7, 30
  days in a row), Pocket rest (a spend-free day), Saver in the making (10),
  Honest with myself (5 expenses marked), Clear mind (7 days without a regret
  after marking 5), Dream come true (a goal reached), Clean slate (a loan
  settled), Gold keeper (a piece of gold or silver).

## Rules
- A day counts for the streak when any entry was written that day (balance
  adjustments are not entries). The running streak ends today, or yesterday when
  nothing is written yet today, since today is not over.
- A *spend-free day* is a day, from the first day anything was written up to
  yesterday, with no expense. Income and transfers do not spoil it. *This
  month* counts from the 1st.
- A badge is kept for ever once won (it uses the best streak, not the current one).
- Nothing is stored: everything is worked out from the entries, goals, loans and
  gold (`badges.dart`, `ActivityQueries.activityDays`, `FeelingQueries`).

## Tests
- `test/features/fun/domain/badges_test.dart`
- `test/features/fun/presentation/badges_ui_test.dart`
