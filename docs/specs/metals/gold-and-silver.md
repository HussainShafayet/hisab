# Gold & silver

## Goal
Keep the gold and silver a family holds (a necklace, bangles, coins) in
bhori / ana / roti, see what it is worth today, and let zakat count it.

## Behaviour
- **More > Gold & silver**: a *Total worth* card (with the weight of each
  metal), the *Prices* of a bhori, and *Your pieces*.
- **Prices**: *Price of 1 bhori of gold (22K)* and *of silver (pure)*, typed, or
  the *Today's price* button, which fetches the market price from the internet
  and fills both. A note says the jeweller's price is usually higher. When
  the price was typed or fetched earlier, the date is shown.
- **Add piece** (button) opens a sheet: gold or silver, a name (quick picks:
  Necklace, Ring, Bangles, Earrings, Coin, Bar), how pure (gold 24K / 22K /
  21K / 18K, silver Pure / Sterling), the weight in *Bhori / Ana / Roti* or
  in *Gram*, what it cost (optional). A line under the weight shows grams,
  bhori and, when the price is known, what it is worth. Tapping a piece edits
  it; *Delete* asks first.
- Without a price for a metal, its pieces show `-` and the card asks for the
  price.
- **Zakat** gets a switch *Add my gold and silver* (only when there are pieces)
  with their worth beside it. The old free-text field is now *Other savings*.

## Rules
- 1 bhori = 11.664 g = 16 ana = 96 roti; weight is kept in milligrams, a roti
  is 121.5 mg (a half milligram rounds up). Shown to the nearest roti.
- Purity is parts per thousand: 24K = 1000, 22K = 917, 21K = 875, 18K = 750,
  pure silver 1000, sterling 925.
- `worth = milligrams x purity x price of a gram of the pure metal / 10^6`,
  rounded to the nearest poisha. The price of a gram is stored; the screen
  shows and takes the price of a bhori (22K gold, pure silver):
  `gram = bhori price x 10^6 / (11664 x quoted purity)`.
- The market price is `ounce price in USD x taka per USD / 31.1034768`, the same
  as zakat's *Today's price*, from `api.gold-api.com` and `open.er-api.com`.
  A failed fetch changes nothing and says so; typing always works.
- A name is 1 to 60 letters, the weight above zero, purity 1 to 1000, the
  price paid zero or more.
- Prices live in `app_settings` (`metals.gold_gram`, `metals.silver_gram`,
  `metals.prices_at`) and are not part of a backup. The pieces are: schema v11
  (`metal_holdings`), backup format 9 (`metalHoldings`; an older file has none).
- Zakat's `zakat.count_metals` setting (default on) decides whether the worth
  is added to what you have.

## Tests
- `test/features/metals/domain/metals_test.dart`
- `test/features/metals/data/metals_repository_test.dart` (rules, prices, backup)
- `test/features/metals/presentation/metals_screen_test.dart` (screen, zakat)
- `test/core/database/migration_test.dart` (version 10 to 11)
