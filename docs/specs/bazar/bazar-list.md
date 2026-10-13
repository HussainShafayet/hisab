# Bazar list

## Goal
Plan the shopping, know roughly what it will cost, and turn what was bought
into one expense, with prices remembered for the next list.

## Behaviour
- **More > Bazar list**. At the top, a field to add an item (the add button or
  the keyboard's done), and below it chips of remembered prices
  (`Rice - 120.00`): tapping one adds that item with its price. Typing narrows
  the chips to the names that contain the text. Empty, the list invites the
  first item.
- Each row has a checkbox (bought), the name (struck through once ticked), `N x
  price` (or just the price, or *No price yet*) and the line total. Ticked items
  sink to the bottom. Tapping a row edits name, how many and the price of one;
  swiping it away deletes it.
- A bar at the bottom shows *Estimated X* for the whole list, how many are
  ticked and what they come to (or *Tick what you bought*), and how many items
  have no price. **Done shopping** (on once something is ticked) opens the add
  transaction form with the ticked total as the amount and `Bazar: Rice, Egg` as
  the note. Once that is saved, the ticked items leave the list and their prices
  are remembered; if the form is left unsaved, nothing changes.

## Rules
- A name is 1 to 60 characters; how many is 1 to 9999; a price is not negative.
- Adding an item without a price takes the remembered price for the same name
  (trimmed, any case, inner spaces squeezed to one).
- A price is remembered when an item with a price is edited and when shopping is
  finished; a newer price for the same name replaces the older.
- Totals: line total = price x how many; items without a price count as 0.
- The note is cut to 500 characters.
- Schema version 10 adds `shopping_items` and `item_prices`. Backup format 8
  saves both; an older file reads as having none.

## Tests
- `test/features/bazar/domain/shopping_test.dart`
- `test/features/bazar/data/bazar_repository_test.dart`
- `test/features/bazar/presentation/bazar_screen_test.dart`
- `test/core/database/migration_test.dart` (version 9 to 10)
