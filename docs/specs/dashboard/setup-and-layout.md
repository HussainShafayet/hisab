# Setup checklist and choosing what Home shows

Phone feedback (2026-11-05): "existing ja ja ache oigulo ke aro user friendly kemne kora
jay". The user then said to do everything; these are the recommended items that
were not already there.

## Behaviour
- **Get started** (`setup-checklist`) on Home: *Get started: 2 of 4* with four
  steps, each one tap from where it is done: write the first entry, set this
  month's budget, make the first backup, turn on the Google Drive backup. A done
  step has a tick and no tap. The card leaves when all are done, or for good with
  its cross (`setup-dismiss`, device setting `setup_dismissed`).
- **Choose what Home shows** (`home-customize`, the slider button in the app bar):
  a switch for quick buttons, safe to spend, plans and loans, top spending,
  recent, and the Takka/streak/insights section (`home-section-<name>`), saved as
  `home_hidden`. The total balance, what needs doing and this month's summary
  always stay.

## Not done
A screen-by-screen audit of empty states, global search and a home-screen widget
from the list of ideas were not built.

## Tests
`test/features/dashboard/domain/home_layout_test.dart`,
`test/features/dashboard/presentation/setup_and_layout_test.dart`.
