# Leave without saving?

## Goal
A slip of the thumb on the back button must not throw away a form the person
has been typing in.

## Behaviour
- On the add / edit forms of a transaction, account, category, goal, loan,
  investment, recurring rule and challenge: going back (the back arrow, the
  phone's back button or swipe) with something typed asks **Leave without
  saving?** *What you typed here will be lost.* with **Keep editing** and
  **Leave**.
- Nothing typed (or typed and then put back as it was): going back is
  immediate, no question.
- Saving closes the form by code and is never asked about. *Save & new* clears
  the fields, so going back after it is immediate too.

## Rules
- `DiscardGuard` and `TextSnapshot` in `lib/core/widgets/discard_guard.dart`.
  A form makes a `TextSnapshot` of its text fields (they are the part a person
  loses) and wraps its Scaffold in a `DiscardGuard`. It uses `PopScope` with
  `canPop: !snapshot.changed`, so with nothing typed the system back gesture
  keeps its normal animation.
- A choice made with a chip or a switch alone (an account, a date) is not
  counted as typing: it is quick to pick again.
- Not covered on purpose: the Add several screen, whose rows are saved one by
  one and keep what could not be saved.

## Tests
`test/core/widgets/discard_guard_test.dart` (on the goal form: nothing typed,
asks, keep editing, leave, saving does not ask).
