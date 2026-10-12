# Add / edit account

## Goal
Making an account takes a few taps: pick the kind, tap a name, type the
opening balance if there is one.

## Behaviour
- A card at the top shows how the account will look and follows what is typed.
  A new account shows its opening balance as the balance; editing shows no
  balance (the opening balance is only part of it).
- **Kind of account**: four large tiles (Cash, Mobile banking, Bank, Card),
  each with its color and icon; the chosen one is outlined and checked.
- **Name** with one-tap quick picks for the chosen kind (bKash, Nagad, Rocket,
  Upay; Debit card, Credit card, ...). A pick fills the name; the name that is
  already typed is not offered again. No quick picks when editing.
- **Opening balance**: optional, may be negative, up to two decimals.
- **Include in total balance** switch.
- The Add account / Save changes button is pinned below the form.
- Opens without the keyboard, so the quick picks are not hidden by it.

## Rules
- A name is required; the repository rejects a duplicate name (case-insensitive)
  and shows its message under the form.
- An opening balance that is not an amount (more than two decimals, letters)
  is rejected with "Enter a valid amount, like 1500 or 1500.50".
- Suggestions come from `accountNameSuggestions(type)`.

## Tests
- `test/features/accounts/presentation/accounts_screen_test.dart` (groups
  "adding an account", "editing an account")
- `test/features/accounts/domain/account_suggestions_test.dart`
- `test/features/transactions/presentation/small_screen_test.dart` - the form
  with a long name and a huge balance at text x1.0 and x1.5.
