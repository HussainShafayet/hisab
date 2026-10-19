# User guide

## Goal
Anyone can learn what a part of Hishab is for and how to use it without asking
anyone: one guide for the whole app and a page for every feature, in English and
Bangla, offline.

## Behaviour
- **More > Help & guide** (the first, highlighted row) opens the guide.
  - A search field over every topic (title, summary, headings and points, in the
    language the app is in; all words must match). Empty results say so.
  - Without a search the topics are listed under groups: *Start here*, *The
    basics*, *People and plans*, *Daily life and faith*, *Extras*, *Your data*,
    *Questions*. Each row has an icon, the title and a one-line summary.
- A **topic** page shows the summary, then its sections: a heading and points.
  Some sections are numbered steps (*Start here > Set up in five steps*). A
  topic about a screen has an **Open <feature>** button that goes there.
- Every screen has a **?** at the top (the *help button*) that opens its topic:
  Home, Transactions (and the add form, Add several), Budget, Reports, Accounts,
  Categories, Loans, Split a bill, Savings goals, Recurring, Trips & events,
  Investments, Bazar list, Zakat, Gold & silver, Badges (Takka, streaks and
  wrapped), Backup & export, Settings.
- Topics: Start here, Home, Transactions, Accounts, Categories, Budget, Reports,
  Loans, Split a bill, Savings goals, Recurring, Trips & events, Investments,
  Bazar list, Zakat, Gold & silver, Takka/streaks/wrapped, Alerts and
  reminders, Backup & export, Settings, Questions and words (a short FAQ and the
  words used: dhar, baki, kacha bazar, bhori, ana, roti, nisab, salami, fitra).
- **More** is in groups (Money, Plans and shopping, Trips and sharing, Faith, For
  fun, Setup) and each row has one line saying what it is for.
- **Home** shows a *Welcome to Hishab* card to someone who has written no entry
  yet, with *Take the tour* (opens *Start here*) and *Not now*. Either puts it
  away for good (`app_settings` key `welcome_dismissed`). Someone with entries
  never sees it.

## Rules
- The text lives in `lib/features/help/domain/guide_content.dart` (English) and
  `lib/core/l10n/bn_guide.dart` (Bangla); a topic is a `GuideTopic` of
  `GuideSection`s (see `guide.dart`). Texts go through `tr`, so the usual Bangla
  coverage test checks every one has a translation.
- **Keep the guide in step with the app.** When a feature is added, changed or
  removed, change its topic (and its Bangla) in the same commit as the code and
  the spec. A new screen gets a topic and a `HelpButton('<topic id>')` in its app
  bar, and its route is added to the test below.
- A topic's `route` is where *Open* goes: a tab (`/transactions`, `/budget`,
  `/reports`) is switched to, a `/more/...` page is pushed.
- Keep points short and plain: what it is, the steps, what to watch for. No
  jargon without the explaining word nearby; the FAQ holds the words.

## Tests
- `test/features/help/domain/guide_test.dart` (the content is whole, every
  feature has a topic, search)
- `test/features/help/presentation/help_ui_test.dart` (More, the guide, the help
  button on every screen, the welcome card)
- `test/core/l10n/bn_strings_test.dart` (every guide text has Bangla)
