# Spending challenges

## Goal
Make saving a game: "no rickshaw for a week", "food under ৳5,000 this month".
The person picks a dare, the app keeps score from the entries already being
written, and Home shows how it is going.

## Behaviour
- **More > Challenges** lists the challenges under *Running now*, *Coming up*
  and *Finished*. Each card has an icon for where it stands, its name, what it
  is about and its dates, a bar, and one line on its state. The menu has
  *Edit* and *Delete* (after asking). With none, an empty state invites the
  first one. The **?** button opens the *Challenges* topic of the guide.
- **New challenge** (or *Edit*) is a form:
  - *Spend nothing* or *Stay under a limit* (a limit adds *Spend at most*).
  - *What it is about*: *All spending* or an expense category; a category
    counts what is inside it too.
  - *How long*: 3, 7, 14 or 30 days, or *Starts on* and *Ends on* dates. The
    default is 7 days from today. Moving the start keeps the length.
  - *Name*: made from the choices (*No Rickshaw spending for 7 days*, *Spend
    under ৳5,000.00 in 30 days*), and kept as typed once the person writes
    their own.
- The status line says: *Starts tomorrow* / *Starts in N days*; *Day 3 of 7 ·
  5 days to go* (no-spend) or *৳500.00 left to spend · 3 days to go* (limit),
  *Last day*; *Completed: nothing spent!* / *Completed: you stayed within the
  limit.*; *Broken: ৳X spent* / *৳X over the limit*.
- **Home** shows a *Challenge* card for the running challenge that ends
  soonest (with *+N more* when there are others). It is not there when none is
  running.
- A challenge that was **won** since the last visit gets confetti when the
  screen is opened (once; not when Fun mode is off, or for a win that ended
  more than a week ago).

## Rules
- A challenge is saved with: name (1 to 60 letters), kind, category (or none),
  limit (poisha; zero for no-spend), first and last day (both included, at
  midnight), created time. Table `challenges`, schema 15.
- At most 366 days; the end cannot be before the start; a limit challenge
  needs a limit above zero; a category must exist, be an expense category and
  not be archived (a challenge keeps one that was archived later).
- What was spent is **never saved**: it is the expenses from the first
  midnight to the end of the last day, in the category and everything inside
  it at any depth (all expenses without a category). Transfers, income and
  balance adjustments are not spending (`ChallengesDao.watchWithSpent`).
- State (`ChallengeItem.stateOn(today)`): *broken* as soon as spending is above
  the limit (any spending for no-spend), even before the last day; otherwise
  *upcoming* before the first day, *won* after the last day, *active*
  between.
- The "cheered" mark of a win is kept in the app settings
  (`challenge_cheered_<id>`), so a win is cheered once (`takeNewWins`).
- It is in the backup (format 12, `challenges`); an older file has none.
- Fun mode does not hide the cards; it only stops the confetti and the motion.

## Tests
- `test/features/challenges/domain/challenge_test.dart`
- `test/features/challenges/data/challenges_repository_test.dart`
- `test/features/challenges/data/challenges_backup_test.dart`
- `test/features/challenges/presentation/challenges_ui_test.dart`
- `test/core/database/migration_test.dart` (schema 15)
