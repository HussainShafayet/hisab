# Eid and festival funds

## Goal
Eid, Qurbani and Pohela Boishakh cost money all at once. Show how many days are
left and make it one tap to start a savings goal for it.

## Behaviour
- **Savings goals > Coming up**: a card for Eid-ul-Fitr, Eid-ul-Adha (Qurbani)
  and Pohela Boishakh, nearest first. Each shows its date (*About* for the
  Eids), the days to go (*Eid Mubarak!* / *Shubho Noboborsho!* on the day)
  and either:
  - *Start a fund*: opens the new goal form with the name (*Eid-ul-Fitr
    2027*), the day and the gift icon filled in; the person only types the
    target; or
  - the fund: a progress bar, saved of target, and *Put aside X a month* (or
    *The fund is ready!*). A tap opens the goal.
- A note says the days of Eid are a guess: the moon decides. The day of a fund
  can be changed in the goal like any goal's.
- **Home** shows the same card for the nearest festival once it is 120 days
  away or less (nothing before that).

## Rules
- Eid-ul-Fitr is 1 Shawwal, Eid-ul-Adha is 10 Dhul Hijjah, from the tabular
  Islamic calendar (`festival.dart`); it was within a day of Bangladesh's Eid
  in 2024-2026. Pohela Boishakh is 14 April.
- A festival's *fund* is any goal whose day is within 3 days of the festival
  day; there is no link stored, so a goal whose day is moved further away is
  no longer shown as the fund. No schema change.
- The next day is today or later; the day after a festival moves to next year.
- Nothing is saved by the cards themselves; money still goes into the goal as
  for any goal (it earmarks, it does not move money).

## Tests
- `test/features/goals/domain/festival_test.dart`
- `test/features/goals/presentation/festival_ui_test.dart` (Goals screen, form
  prefill, Home card)
