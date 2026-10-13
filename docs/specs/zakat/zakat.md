# Zakat

## Goal
Give a rough answer to "how much zakat do I owe?" from what Hishab already
knows, with the price of silver or gold either typed or fetched from the
internet, and a yearly reminder of the zakat day.

## Behaviour
- **More > Zakat**, one screen, worked out as you change things:
  - *What you have*: a tick for each account (not credit cards), the balance
    beside it; a switch *Add money others owe you* (loans you gave, what is left
    of them); *Gold, silver and other savings* typed by hand.
  - *What you owe*: a switch *Take off your debts and card bills* (loans you
    took, what is left, plus what credit cards owe).
  - *Nisab*: silver (612.36 g) or gold (87.48 g), the *Price of one gram* typed,
    or *Today's price* to fetch it. Changing between silver and gold clears the
    price, as the two cost differently.
  - *Result*: You have, You owe, Left to count, Nisab, and then *Zakat due*
    (2.5% of what is left to count) or *Your wealth is X under the nisab, so no
    zakat is due*, or, without a price, *Enter the price of a gram...*
  - *Yearly reminder*: pick a day; a notification at 9 in the morning every
    year on that day (28 February in a year without the 29th). Cleared with the x.
- What is entered is remembered.

## Rules
- Only an account with money counts (an overdrawn one counts as nothing), and
  only the ticked ones. A credit card is never savings; what it owes is a debt.
- `net = max(0, assets - debts)`; nisab = grams x price of a gram;
  due when `net >= nisab`: `ceil(net x 25 / 1000)` poisha.
- Price of a gram from the internet = (price of a troy ounce in US dollars x
  taka per dollar) / 31.1034768 g. Gold and silver prices come from
  `api.gold-api.com`, the taka rate from `open.er-api.com`; both are free and
  need no key. If they cannot be reached, a message says so and the price can
  be typed.
- Settings are kept in `app_settings` under `zakat.*` keys: basis, gram price,
  other savings, accounts left out, the two switches, and the reminder day
  (`month-day`). They are not part of a backup.
- The reminder is part of the usual reminders (`reminderSyncProvider`).
- The app asks for the INTERNET permission only for this and for *Use today's
  rate* on a dollar entry; nothing is sent, and nothing else needs the internet.

## Tests
- `test/features/zakat/domain/zakat_test.dart`
- `test/features/zakat/data/zakat_settings_test.dart` (settings, the reminder)
- `test/features/zakat/presentation/zakat_screen_test.dart`
- `test/core/net/rate_service_test.dart`
