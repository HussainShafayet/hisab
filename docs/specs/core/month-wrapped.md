# Month wrapped

## Goal
End the month with a short, friendly story of it in swipeable cards, a bit like
a year-in-review, so looking back is a treat and not a chore.

## Behaviour
- **More > Month wrapped** opens it any time; on **Home** (Fun mode only) a card
  *Your October 2026 wrapped is ready* appears in the last 4 days of a month and
  the first 5 days of the next, for the month that just ended or is ending.
  It is not offered when nothing was written in that month.
- Cards (swipe, with dots): *who you were* (a playful title from the top
  category: The Foodie, The Traveller, ...), *Money in, money out* (spent, earned,
  kept or overspent), *Most of your money went to* (top category, amount, share),
  *Your biggest single spend* (amount, category, day, note), *Days you showed up*
  (entries and days with no spending), *How it felt* (only when expenses were
  marked: regret, needed, wanted, Takka's line), then *See you next month!* with
  a **Done** button. An empty month is one card saying nothing was written.
- Nothing is stored; it is worked out each time.

## Rules
- The data comes from the report queries: income and expense leave out
  transfers and balance adjustments (`ReportsRepository`), the top category is
  the top-level one with the most spending, the biggest spend is the largest
  single expense of the month.
- Days with no spending are counted from the 1st (or the first day anything was
  written) up to the last day of the month, or yesterday in the running month
  (`spendFreeDays`).
- Not shareable as a picture yet; a screenshot works.

## Tests
- `test/features/fun/domain/wrapped_test.dart`
- `test/features/fun/presentation/wrapped_ui_test.dart`
