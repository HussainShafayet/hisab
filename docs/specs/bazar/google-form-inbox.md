# Bazar list from a Google Form

## Goal
One or two people write what to buy in one place, and Hishab shows it, with no
server. Google Keep cannot be read by other apps, and a Google Tasks list cannot
be shared. A Google Form can be filled by anyone with its link, no account and no
app, and it writes each answer as a row of a Google Sheet, which can be published
as CSV and read without signing in.

## Behaviour
- **Set up (once, in Google):** a Form with a question *Item* (**paragraph**, so one
  answer can hold many things, required) and, if wanted, *Quantity*; *Responses > Link to Sheets*; in that
  sheet *File > Share > Publish to web > CSV*. Collect email addresses and Limit
  to 1 response stay off.
- Bazar list > menu > **Add from a Google Form**: a dialog asks for the link of the
  published sheet and, if wanted, the link of the form (*Send > link*). The sheet is
  read to see it works. When it already has answers: *The sheet already has N
  answers. Add them to the list?* with **Yes, add them** or **Only new ones**.
- A line under the app bar: *Google Form · Synced 25 Oct, 10:30 am.*, *Not synced
  yet.*, or the problem in red (with Google's line).
- New answers come onto the list when the **screen opens** and with **Sync now**
  (*Added 2 items from the form.* / *No new items in the form.*). An answer's
  quantity is taken when there is a *Quantity* column; the remembered price of the
  name is used, as for any item added.
- **Send the form link** (when the link of the form was given) opens the share
  sheet with it, for the people who add to the list.
- **Stop adding from the Google Form** forgets the links. What is on the list
  stays.

## Rules
- Only `https://docs.google.com/spreadsheets/...`: a published link (`.../pub`, made
  `output=csv`) or the link of a sheet anyone with the link can view (`.../edit`,
  made `.../export?format=csv`). Anything else: *Paste the link from File > Share >
  Publish to web...*
- A page of HTML instead of CSV (Google asking to sign in) or a 403/404 means the
  sheet is not published: *Google did not show the sheet...*
- An answer holding several things is split at line breaks, commas and semicolons;
  a list mark (`-`, `*`, a bullet, `1.`) is taken off the front of each. *Rice, egg*
  and two lines *Rice* / *Egg* both give two items. A quantity column is only read
  for an answer with one thing.
- The Item column is the first whose title has *item*, *jinis* or *name*, else the
  second (the first is the time). The quantity column's title has *quantity*, *qty*
  or *how many*; 1 to 9999, else 1.
- **What was taken is told by how many rows**, not which: answers only ever get
  added, so the rows after the count are new (`planFormImport`). So an answer
  comes in once, even after it was bought and taken off the list, and nobody has
  to delete rows. A sheet with fewer rows than the count was cleaned: nothing is
  taken and it counts from there. A row with no item is counted, not added.
- The links, the count, the time and the problem are device settings (`bazar_form_*`,
  `last_form_sync_at`) and stay out of backups.
- One way only: the list takes answers, it sends nothing back. Google shows a new
  answer in the published CSV after a few minutes. Anyone with the link of the
  sheet can read it.
- No sign-in and no Google Cloud setup: plain HTTPS (`dart:io`) to Google.

## Tests
`test/features/bazar/domain/form_inbox_test.dart`,
`test/features/bazar/data/form_inbox_service_test.dart` and
`test/features/bazar/presentation/form_inbox_ui_test.dart`, on a fake gateway
(`test/helpers/fake_form_inbox_gateway.dart`). The real fetch from Google cannot
run in tests: try it on the phone.
