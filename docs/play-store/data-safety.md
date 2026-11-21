# Play Console: Data safety and other declarations

Suggested answers, from what the app really does (checked in the code on
22 November 2026: no analytics, ads or crash libraries; hosts are open.er-api.com,
api.gold-api.com, cdn.jsdelivr.net and Google for Drive; all over HTTPS). They
are your answers to give: read each question in the form before you submit.

## Data safety
- Does your app collect or share any of the required user data types? **No.**
  Nothing from your records is sent to the developer or to a third party for the
  developer's use. The optional Google Drive backup is a transfer to the user's
  own Drive that the user starts; the developer cannot see the file. If the form
  asks, that is the one thing to explain.
- Is all of the user data collected by your app encrypted in transit? Not
  applicable (nothing is collected). The app's network calls use HTTPS.
- Do you provide a way for users to request that their data is deleted? Data is
  only on the phone: delete it in the app or uninstall. A Drive backup is deleted
  by the user in Drive.

## App content
- Privacy policy: the URL of `privacy-policy.md` once it is on the web, with your
  contact email filled in.
- Ads: **No ads.**
- App access: all features work without an account or a login. No access
  instructions needed.
- Content rating questionnaire: answer **No** to violence, sexual content,
  language, controlled substances and gambling; no user generated content and no
  sharing of location. Expected rating: Everyone.
- Target audience: 18 and over (not for children).
- News app: No. Government app: No. Health: No (it has no health features).
- Financial features: it tracks personal money and loans between people; it does
  not hold money, make payments, lend, trade or offer insurance or crypto. Choose
  the option that matches personal finance tracking and none of the lending,
  payments, trading or crypto ones.
- Advertising ID: the app does not use it (answer No).
- Permissions: only normal ones (internet, notifications, boot completed,
  vibrate). No SMS, call log, contacts, location, camera or microphone. The
  biometric entries in the manifest come from a library and are not used by the
  app. No exact alarm permission.
