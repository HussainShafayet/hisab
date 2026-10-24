# Search on More

## Goal
More lists about twenty places in six groups. Finding one by scrolling is slow
when you know its name (zakat, backup, loans).

## Behaviour
- A search box at the top of the More tab: *Search: zakat, loans, backup*.
- Typing shows only the places whose name or one-line description holds the
  text (not case sensitive), in one short list without headings. Help & guide
  is searched too. A cross in the box clears it and brings the full list back.
- Nothing matches: *Nothing matches "{text}".*
- A tap opens the place, as in the full list.

## Rules
- `MoreScreen` keeps its places as `_Entry` values in groups; the same entries
  feed the full list and the search.
- The text is matched against the shown (translated) title and description, so
  it works in English and in Bangla.

## Tests
`test/features/settings/presentation/more_search_test.dart`. The test helper
`tapMoreRow` names the list's own scrollable, because the search box has one too.
