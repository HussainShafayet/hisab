# UI audit: tap size, labels, layout, contrast

Phone feedback (2026-11-21): "full app er UI ta aro polish kora jay, user
friendly jate hoy". There was no written UI rulebook; this is the part of it
that a test can check, so it stays true.

## Rules
- **Tap targets are at least 48 x 48 dp** (Android guideline). A small icon
  gets a 48 dp box (the category expand arrow, the Income / Expense figures on
  Reports).
- **Every tap target has a label** (a tooltip or text a screen reader can say).
- **Nothing overflows** on a 360 x 740 dp phone: at normal text, at text x1.5
  and in Bangla (text x1.3). Text widths are only true with the real font, so
  the audit loads Roboto (`loadRealFonts`); the test font makes text far wider
  and shows overflows that are not there.
- **Text is readable on every surface**: 4.5:1 for text, 3:1 for icons and
  outlines, in the light and the dark theme. Measured from the theme's colors
  (`onSurface`, `onSurfaceVariant`, `primary`, `error`, income, expense, the
  `on...Container` pairs against `surface`, `surfaceContainerLow`,
  `surfaceContainer`, `surfaceContainerHighest`). Flutter's pixel based
  `textContrastGuideline` is not used: on real screens it reads 1.2 to 1.9 for
  text the theme draws at 8:1.
- **Colors come from the theme** (`colorScheme`, `FinanceColors`). Kept on
  purpose: white on the colored hero cards (account cards, the Home card), the
  mascot and the confetti. The light theme's income green and expense red were
  darkened (`0xFF276B2B`, `0xFFBB2323`) so they pass 4.5:1 on cards and chips.
- **A screen that cannot load offers Retry** (`ErrorView.onRetry`, which
  invalidates the provider the screen watches).

## What the audit does
`test/accessibility/ui_audit_test.dart` opens Home, Transactions, Budget,
Reports and every row of More (Help first, while the list is at its top), and
lists what is wrong by screen and place in the code. Four runs: light, dark
(tap size and labels), text x1.5 and Bangla (layout). A screen that does not
open is a failure too.
`test/core/theme/theme_contrast_test.dart` checks the contrast of the colors.
`test/features/challenges/presentation/error_retry_test.dart` checks Retry.

## Found and fixed
- Categories: the expand arrow was 40 dp wide. Reports: the Income and Expense
  figures were 40 dp high.
- Metals: a white icon on the gold and silver circles (about 2.3:1) is dark now.
- Hidden income: the bar at 80% used `Colors.orange`; it uses the theme's
  warning color.
- Loan screen: "Add a payment" broke into two lines at 360 dp; the two buttons
  share the width 3:2 with less padding.
- Charge dialog: the expense switch and account come right after the amount,
  not below the date and note; "Another charge" is "Other" on the chips.
- 18 error screens had no Retry.

## Not done
- A look at every screen's picture (light, dark, Bangla) by a person.
- Screen reader order and the wording of labels on custom widgets (only the
  presence of a label is checked).
- Tablet and landscape.
- Fewer taps: optional fields folded away, Undo instead of questions.
