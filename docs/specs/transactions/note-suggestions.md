# Note suggestions

## Goal
Most notes are written again and again (*Lunch with Rahim*, *Rickshaw*). Tap
one instead of typing it, and get its category and amount too.

## Behaviour
- On the add / edit form, while the **Note** field has focus, notes from earlier
  entries appear as chips under it (an expense is offered expense notes, an
  income income notes; a transfer none).
- Nothing typed: the notes written most often. Something typed: notes that
  hold it, the ones that start with it first, then the most often written.
  A note equal to what is typed is not offered again.
- Tapping a chip fills the note. It also fills the **category** and the
  **amount** of the newest entry with that note, but only where the form has
  none yet, and only a category that can still be used.

## Rules
- Pure `suggestNotes` in `transactions/domain/note_suggestion.dart`: groups by
  the lower-cased note, at most four chips, the newest entry with a note says
  which category and amount to offer.
- The notes are the newest 400 income / expense entries with a note
  (`NoteQueries.pastNotes`, no transfers, no balance adjustments), read once when
  the form opens (`pastNotesProvider`).
- Works offline, nothing is sent anywhere.

## Tests
`test/features/transactions/domain/note_suggestion_test.dart` and
`test/features/transactions/presentation/note_suggestions_ui_test.dart`.
