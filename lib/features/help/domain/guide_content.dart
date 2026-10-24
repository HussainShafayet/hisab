// The text of the user guide (see docs/specs/help/user-guide.md). Keep it in
// step with the app: change a feature, change its topic here and its Bangla in
// bn_guide.dart.
import 'package:flutter/material.dart';
import 'package:hishab/core/router/app_routes.dart';
import 'package:hishab/features/help/domain/guide.dart';

/// The groups the guide is listed under.
const guideGroups = <GuideGroup>[
  GuideGroup('start', 'Start here'),
  GuideGroup('basics', 'The basics'),
  GuideGroup('people', 'People and plans'),
  GuideGroup('life', 'Daily life and faith'),
  GuideGroup('extras', 'Extras'),
  GuideGroup('data', 'Your data'),
  GuideGroup('questions', 'Questions'),
];

/// Every topic of the guide, in the order they are listed.
const guideTopics = <GuideTopic>[
  GuideTopic(
    id: 'start',
    icon: Icons.rocket_launch_outlined,
    group: 'start',
    title: 'Start here',
    summary: 'Five minutes to set Hishab up and write your first entry.',
    sections: [
      GuideSection('Set up in five steps', steps: true, [
        'Open More > Accounts and check your wallets: cash, bKash, bank. Add the ones you use, and type what each holds now as the opening balance.',
        'Tap the + button on Home or Transactions and write your first expense: the amount, a category, the wallet it came from.',
        'Write things down the same day, even small ones. Rickshaw 50 matters as much as rent.',
        'Open Budget and set how much you want to spend this month. Home will then tell you how much is safe to spend today.',
        'Take a backup now and then from More > Backup & export. Your data lives only on this phone.',
      ]),
      GuideSection('Good to know', [
        'Hishab works without the internet and never sends your data anywhere.',
        'Money is always in takka. Amounts keep their paisa, like ৳1,250.50.',
        'Every screen has a ? button at the top. It opens the guide for that screen.',
        'Hishab is made for how money moves in Bangladesh: bKash and Nagad messages, dhar and baki, Eid funds, zakat in bhori and ana, and a screen in Bangla.',
        'The More tab has a search box at the top: type zakat, loans or backup to find a place without scrolling.',
        'If you go back from a form with something typed, Hishab asks before it throws the typing away.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'home',
    icon: Icons.home_outlined,
    group: 'basics',
    title: 'Home',
    summary: 'Where you stand today, on one screen.',
    sections: [
      GuideSection('What the cards show', [
        'The order is: total balance and wallets, what needs you (a bill, an account below zero, a backup), shortcuts, what you can spend today, this month, plans and loans, top spending and recent entries.',
        'Habits, tips and fun is closed until you open it: Takka, your streak, how the month felt and tips. Tap its bar to open or close it. Home remembers.',
        'Takka, the coin, lives under Habits, tips and fun at the bottom. It says something short and sometimes funny. Tap it for another line.',
        'Total balance is the sum of your accounts. Accounts marked Not in total are left out.',
        'Safe to spend today divides what is left of the month\'s budget by the days left, after the bills still to come. It needs a budget.',
        'Can I afford it? on that card checks a price you type before you buy.',
        'Wallets show each account. Loans, Investments and Streak cards appear when you have them.',
        'A warning card means an account holds less than nothing: an entry is probably missing or on the wrong wallet.',
      ]),
      GuideSection('Shortcuts', [
        'The row under the wallets jumps to Loans, credit card bills and Savings goals.',
        'The + button adds a transaction. In its form, the Add several button at the top adds many at once.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'transactions',
    icon: Icons.receipt_long_outlined,
    group: 'basics',
    title: 'Transactions',
    summary: 'Write down income, expenses and transfers, and find them again.',
    route: AppRoutes.transactions,
    sections: [
      GuideSection('Adding one', steps: true, [
        'Tap +. Choose Expense, Income or Transfer.',
        'Type the amount. The calculator button is there when you need to add things up.',
        'Pick the category and the account. The preview under the account shows what will be left. For a transfer, From is above To, with a swap button between them.',
        'Add a note or the day if you like, then Save. Save & new keeps the form open for the next one.',
      ]),
      GuideSection('Faster ways', [
        'Quick type: write one line like rickshaw 50 or bazar 450 bkash or +salary 30k, and the form fills itself. Add yesterday, gotokal or 2 days ago to set the day.',
        'Paste an SMS: copy a bKash, Nagad or bank message, then tap the SMS button beside the quick line. The amount, fee, account and day fill in, and the note keeps the TrxID, so the same SMS cannot be added twice. A cash out becomes a transfer to Cash with its fee. If the balance in the SMS is not what the app would show, you are told something may be missing.',
        'Note suggestions: as you type a note, notes from earlier entries appear under it. Tap one to fill the note, and the category and amount of that entry if they are still empty.',
        'Add several: enter a handful of transactions on one screen and save them together. Paste lines turns lines like rickshaw 50 into rows.',
        'Needed, Wanted or Regret on an expense lets Home show how the month felt.',
        'A tag (Trips & events) groups the expenses of a trip or an occasion.',
      ]),
      GuideSection('Finding and fixing', [
        'The Transactions tab lists everything, newest first. Use Search to find a note, category or amount, and Filter to narrow the list by type, category, account, dates, an amount range, a trip or event, or how it felt.',
        'Each filter you set shows as a chip under the month; its cross takes just that one off. Save this filter in the sheet keeps a favourite, like "Regret over ৳500", to use again.',
        'Tap a transaction to open it, change it or delete it. Account balances follow at once.',
        'Swipe a row to the left, all the way, to delete it: there is no question, but Undo stays on the screen for 8 seconds. Swipe right, or tap, to change it.',
        'Select several: press and hold a transaction, then tap Select several. Tap more rows, then change their category, change their account, or delete them together. Undo stays for 8 seconds. Transfers and balance fixes can only be deleted this way.',
        'A transfer moves money between your own accounts. It is not income and not an expense.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'accounts',
    icon: Icons.account_balance_wallet_outlined,
    group: 'basics',
    title: 'Accounts',
    summary: 'Your wallets: cash, bKash, bank, cards.',
    route: AppRoutes.accounts,
    sections: [
      GuideSection('Using accounts', [
        'Add an account with the kind (cash, mobile banking, bank, card), a name and the balance it holds now.',
        'Tap a card to edit it. Its menu has Adjust balance, which fixes the balance when it does not match your real wallet.',
        'Archive hides an account you no longer use without losing its old transactions. Show archived brings it back.',
        'Not in total keeps an account out of your total balance, for example money that is not really yours.',
      ]),
      GuideSection('Credit cards', [
        'A credit card is money you owe, not money you have. It shows Owed, the limit and what is left to spend.',
        'Paying the card bill is a transfer into the card, so it is not counted as an expense twice.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'categories',
    icon: Icons.category_outlined,
    group: 'basics',
    title: 'Categories',
    summary: 'Where each taka went: food, transport, rent and more.',
    route: AppRoutes.categories,
    sections: [
      GuideSection('How categories work', [
        'Categories are a tree. Food can hold Kacha bazar, which can hold Fish. A group\'s total is everything inside it.',
        'The defaults follow daily life in Bangladesh: kacha bazar, rickshaw, tuition, salami, fitra. Older installs can add them with the Add them card.',
        'Each category has an amount for this month on the Categories screen, so you see where the money went.',
      ]),
      GuideSection('Adding your own', steps: true, [
        'Tap the add button and type a name. Choose an icon and a colour.',
        'Under Inside, choose the category it belongs to, or leave it at the top. Hishab suggests a place for a new name, like Looks like it goes inside Fish.',
        'Archive a category you no longer use. Old transactions keep it.',
      ]),
      GuideSection('Tidying up', [
        'Two names for the same thing? Open the menu of a category with no sub-categories and choose Merge into. Pick the category to keep. Its transactions, budgets, repeating entries and challenges move there, and the old one is archived. This cannot be undone here, so make a backup first if you are unsure.',
        'Move a category to another place from its Edit screen, under Inside. What is inside it goes with it.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'budget',
    icon: Icons.pie_chart_outline,
    group: 'basics',
    title: 'Budget',
    summary: 'Decide how much to spend, and see if it will last.',
    route: AppRoutes.budget,
    sections: [
      GuideSection('Setting it up', steps: true, [
        'Open the Budget tab and set the overall limit for the month.',
        'Optionally set limits for single categories, like Food. Copy last month\'s budget to save time.',
        'Bars turn amber near the limit and red once it is crossed.',
      ]),
      GuideSection('Carrying over what is left', [
        'Switch on Carry over what is left on the Budget tab. Money you did not spend in a month is then added to the same budget of the next month, with a note on the card.',
        'Only what is left is carried. Overspending does not make next month smaller. A month without that budget starts again from zero.',
        'Edit a budget and tick Do not carry over this budget to keep it out. While the switch is off, the Budget tab tells you how much last month left.',
      ]),
      GuideSection('What it feeds', [
        'Home\'s Safe to spend today uses the overall budget.',
        'Budget alerts (Settings > Alerts) tell you at 85% and 100% of the overall budget.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'reports',
    icon: Icons.bar_chart_outlined,
    group: 'basics',
    title: 'Reports',
    summary: 'See the month in charts and totals.',
    route: AppRoutes.reports,
    sections: [
      GuideSection('What you can see', [
        'Pick a month at the top, or a custom date range with the calendar button. You get income, expense and what you kept.',
        'A pie chart shows spending by category, a bar chart compares income and expense over the last months, and a list shows the biggest expenses.',
        'The category tree card shows each group with everything inside it added up.',
        'Tap Year, above the date, to see a whole year. A bar chart shows each month, and a list gives every month its income, expense and what was left. Tap a month in the list to open it.',
        'Under the list: your average per month, the month you spent most and the month you kept most. Averages count only the months that have entries, so a year you began in October is not pulled down by empty months. The year is compared with the year before.',
        'Transfers and balance corrections are left out, so they never inflate your income or expense.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'loans',
    icon: Icons.handshake_outlined,
    group: 'people',
    title: 'Loans',
    summary: 'Dhar and baki: money you lent and money you borrowed.',
    route: AppRoutes.debts,
    sections: [
      GuideSection('Using it', steps: true, [
        'Tap add and choose I lent (they will pay you) or I borrowed (you will pay them). Enter the person, the amount and, if you like, a pay back day.',
        'Open a loan to record a payment. A progress bar shows how much is paid. All paid closes it in one tap.',
        'Choose an account if the money really moved a wallet, and its balance changes with the loan.',
      ]),
      GuideSection('Reading the screen', [
        'I\'ll get shows what people owe you. I\'ll give shows what you owe, and your credit cards. People shows what is left between you and each person.',
        'A loan is not income or expense. It never changes your reports.',
        'You get a notification the day before and on the due day. For money owed to you, a message you can send is ready.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'split',
    icon: Icons.call_split,
    group: 'people',
    title: 'Split a bill',
    summary: 'Paid for friends? Record it in one go.',
    route: AppRoutes.splitBill,
    sections: [
      GuideSection('How it works', steps: true, [
        'Enter what it was for, the bill total, the account you paid from and the category of your part.',
        'Add your friends by name. Each gets an equal share. Type a number to give someone a different part, or tap Split equally to go back.',
        'Save split. Your part becomes an expense, and each friend\'s part becomes money they owe you in Loans.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'goals',
    icon: Icons.flag_outlined,
    group: 'people',
    title: 'Savings goals',
    summary: 'Save for a laptop, a trip or Eid in small steps.',
    route: AppRoutes.goals,
    sections: [
      GuideSection('Using goals', steps: true, [
        'Add a goal with a name, a target amount and, if you want, a day to reach it by.',
        'Open it and tap Put money in whenever you set something aside. Take out if you spend it.',
        'The goal says what to do next, for example how much to put aside each month to make it in time.',
      ]),
      GuideSection('Good to know', [
        'Goal money is set aside inside the app only. Your account balances and reports do not change.',
        'Eid, Qurbani and Pohela Boishakh funds start with one tap, and Home counts down the days.',
        'Each festival card and each goal has a three-dot menu. On a festival: Change the date once the moon is seen (Eid is only a guess until then), Hide this festival if you do not keep it, and Edit or Delete its fund. Hidden festivals come back with Show hidden festivals. On a goal: Edit or Delete.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'recurring',
    icon: Icons.repeat,
    group: 'people',
    title: 'Recurring',
    summary: 'Rent, bills and salary: enter once, never forget.',
    route: AppRoutes.recurring,
    sections: [
      GuideSection('Setting one up', steps: true, [
        'Tap add. Choose Expense or Income, a name, an amount, a category and an account.',
        'Say how often (every week, month or year) and the first due day. An end day is optional.',
        'Choose one: Add it by itself when it is due, or Remind me on the day.',
      ]),
      GuideSection('When it is due', [
        'Anything waiting shows as a Due now card on Home with Add and Skip.',
        'Pause a rule to stop it for a while, or delete it. What it already added stays.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'trips',
    icon: Icons.luggage_outlined,
    group: 'people',
    title: 'Trips & events',
    summary: 'See what a trip, Eid or a wedding cost in all.',
    route: AppRoutes.tags,
    sections: [
      GuideSection('How to use tags', steps: true, [
        'When you add an income or expense, pick a chip under Trip or event, or make one with New tag.',
        'Save & new keeps the same tag for the next entry, which suits a trip.',
        'Open More > Trips & events to see the total spent, what was received and every entry under each tag.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'investments',
    icon: Icons.storefront_outlined,
    group: 'people',
    title: 'Investments',
    summary: 'Money put into a shop, farm or partnership: is it paying?',
    route: AppRoutes.investments,
    sections: [
      GuideSection('Tracking one', steps: true, [
        'Add an investment with its name and the money you put in first.',
        'Open it to record more money put in, profit received, money taken back, and what it is worth now.',
        'Choose an account for an entry if the money really moved through a wallet.',
      ]),
      GuideSection('How it is counted', [
        'Profit counts as income in your reports. Money put in and taken back does not, as it is your own capital moving.',
        'The summary shows the return in takka and in percent.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'bazar',
    icon: Icons.shopping_basket_outlined,
    group: 'life',
    title: 'Bazar list',
    summary: 'Plan the shopping, know the cost, then save it as one expense.',
    route: AppRoutes.bazar,
    sections: [
      GuideSection('Making a list', steps: true, [
        'Type an item and tap +. The playlist button next to it adds the item with how many and the price.',
        'Chips under the field are prices Hishab remembers. Tap one to add that item with its price.',
        'Tick what you buy. Tap a row to edit it. Each row has a menu to edit or delete, and a delete can be undone.',
      ]),
      GuideSection('Finishing', [
        'Done shopping opens the add form with the ticked total and a note listing the items. Save it and the ticked items leave the list.',
        'The menu at the top has Share the list, which sends what is still to buy as a message, Remembered prices to see, add, edit or remove prices, Remove bought items and Clear the list.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'zakat',
    icon: Icons.volunteer_activism_outlined,
    group: 'life',
    title: 'Zakat',
    summary: 'A rough answer to how much zakat is due.',
    route: AppRoutes.zakat,
    sections: [
      GuideSection('Working it out', steps: true, [
        'Tick the accounts that count. Switch on Add money others owe you if it applies. Type any gold, silver or other savings.',
        'Switch on Take off your debts and card bills to subtract what you owe.',
        'Choose the nisab by silver or gold and type the price of one gram, or tap Today\'s price to fetch it when you are online.',
        'The result shows the zakat due, 2.5% of what is left, or says you are under the nisab.',
      ]),
      GuideSection('Remember', [
        'This is a guide for your own calculation, not a ruling. Ask a scholar if unsure.',
        'Pick a zakat day and Hishab reminds you every year at 9 in the morning.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'metals',
    icon: Icons.diamond_outlined,
    group: 'life',
    title: 'Gold & silver',
    summary: 'Your gold and silver in bhori, ana and roti, valued today.',
    route: AppRoutes.metals,
    sections: [
      GuideSection('Using it', steps: true, [
        'Tap Add piece: choose gold or silver, a name like Necklace, how pure it is, and the weight in bhori, ana and roti (or in grams).',
        'Type the price of one bhori of gold and of silver, or tap Today\'s price to fetch it when you are online. A jeweller usually charges more.',
        'The total shows the worth. Zakat counts it for you.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'fun',
    icon: Icons.celebration_outlined,
    group: 'extras',
    title: 'Takka, streaks and wrapped',
    summary: 'The playful side: a coin mascot, streaks, badges and a story of your month.',
    route: AppRoutes.badges,
    sections: [
      GuideSection('The fun parts', [
        'Takka is a small coin who comments on your day. Fun mode in Settings turns Takka, jokes, confetti and the gentle motion on or off.',
        'Writing something every day grows your streak. Days with no spending count too. Badges reward milestones.',
        'Month wrapped is a short swipeable story of the month. Near the month\'s end it appears on Home. Share a card as a picture with the share button.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'challenges',
    icon: Icons.timer_outlined,
    group: 'extras',
    title: 'Challenges',
    summary: 'Dare yourself to spend less, and see if you can do it.',
    route: AppRoutes.challenges,
    sections: [
      GuideSection('Starting one', steps: true, [
        'Open More > Challenges and press New challenge.',
        'Choose Spend nothing or Stay under a limit, what it is about (all spending, or a category like Rickshaw), and how long.',
        'The Quick start buttons fill it for you: a no-spend day, weekend or week.',
        'The name is made for you. Change it if you like. Start again when it ends repeats the same challenge.',
      ]),
      GuideSection('How it is decided', [
        'Only expenses count. Transfers and balance corrections do not. A category counts what is inside it too.',
        'Going over the limit breaks the challenge at once, even before the last day. Staying within it to the last day wins, with confetti if Fun mode is on.',
        'The running challenge that ends soonest shows on Home.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'alerts',
    icon: Icons.notifications_active_outlined,
    group: 'extras',
    title: 'Alerts and reminders',
    summary: 'Notifications with their own funny sounds. Every one can be switched off.',
    route: AppRoutes.settings,
    sections: [
      GuideSection('What can alert you', [
        'Bills and recurring items, loans and the zakat day remind you ahead of time.',
        'Budget alerts come when the month\'s budget is nearly used up and when it is crossed.',
        'Habit alerts come when the same kind of spending keeps coming back, like the fifth rickshaw this week.',
        'The daily reminder nudges you in the evening if you have not written anything. The wrapped alert tells you when your month is ready.',
      ]),
      GuideSection('Seeing what came', steps: true, [
        'Tap the bell at the top of Home. The number on it counts what you have not opened. The list shows what already came, newest first.',
        'Tap a notification to mark it read and go to the screen it is about. The double tick at the top marks them all as read.',
        'A reminder is listed once its time has passed. If notifications were blocked on your phone, it did not show.',
        'A tap on a notification on your phone opens the screen it is about.',
        'The clear button empties the list. The last 200 are kept, for up to 90 days.',
      ]),
      GuideSection('Controlling them', steps: true, [
        'Open Settings > Alerts. Each alert has its own switch.',
        'Funny alert sounds off means your phone\'s usual notification sound.',
        'If a notification never shows up, check that notifications are allowed for Hishab in your phone\'s settings.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'data-check',
    icon: Icons.fact_check_outlined,
    group: 'data',
    title: 'Data check',
    summary: 'Find entries that may be mistakes, after an import or any time.',
    route: AppRoutes.dataCheck,
    sections: [
      GuideSection('What it looks for', [
        'Entered twice: the same day, kind, amount, account and note, from ৳500. Delete the extra ones, or keep them if both are real. Undo stays for 8 seconds.',
        'Dated in the future: often a wrong year, or a day and month the wrong way round.',
        'Far above the usual: at least 10 times the usual amount of its category and ৳1,000 or more, like a slip of a zero.',
        'In Other: spending that has no real category yet.',
        'Categories that look alike, like Utility and Utilities. Merge them from the Categories screen.',
      ]),
      GuideSection('Good to know', [
        'Nothing is changed unless you say so. Tap an entry to open and fix it.',
        'It looks at every entry you have, so run it after importing a sheet.',
        'Balance corrections are not looked at.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'backup',
    icon: Icons.backup_outlined,
    group: 'data',
    title: 'Backup & export',
    summary: 'Keep your data safe, move it, or open it in a spreadsheet.',
    route: AppRoutes.backup,
    sections: [
      GuideSection('What you can do', [
        'Export a backup saves everything to one file, your settings too. Keep it somewhere safe, like your email or a cloud drive.',
        'Automatic backup (Settings > Data, on by default) saves a copy to Downloads/Hishab when you leave the app after something changed. It stays if the app is removed: reinstall, open Backup & export > Restore and choose Hishab-auto-backup.json from Downloads/Hishab. The file is not locked, and a lost phone takes it too, so keep a copy elsewhere as well.',
        'Home asks you to Send a copy every two weeks. One tap opens the share sheet with the backup ready: choose Google Drive, email or a chat. The copy in Downloads goes with the phone if it is lost or reset, and the one in Drive does not.',
        'The screen shows when you last made one, and Home reminds you after two weeks.',
        'Restore from a backup replaces what is on this phone with the file. Do it on a new phone or after a reset.',
        'Export CSV gives a spreadsheet of your transactions. Import CSV brings in a sheet from another app.',
      ]),
      GuideSection('Importing a sheet', steps: true, [
        'Save your Google Sheet or Excel file as CSV, then open Backup & export > Import from CSV.',
        'Choose the file and say which column is which. If income and expense have a column each, pick "Separate income and expense columns".',
        'Choose the account for the rows, or tap New account to make one here. Turn "Count it in my total balance" off for old records, so your total stays the same.',
        'The preview shows what changes in each account and which categories will be made. If a new category is one you already have, tap Use it or the swap button.',
        'Rows marked "to check" have a date far from the rows around them, often with the day and month the wrong way round. They are imported as they are: fix them afterwards.',
        'The next file with the same column names starts with the same columns.',
      ]),
      GuideSection('If it was a mistake', [
        'Right after an import, tap Undo this import. Later, Backup & export shows Undo last import for the latest one.',
        'Undo removes the transactions that import added. Categories and accounts it made that nothing else uses are hidden, not deleted.',
        'Entries you added by hand are never touched.',
      ]),
      GuideSection('Be careful', [
        'Hishab does not keep a copy online. If you lose the phone without a backup, the data is gone.',
        'Take a backup before you update the app or restore a file.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'settings',
    icon: Icons.settings_outlined,
    group: 'data',
    title: 'Settings',
    summary: 'Language, look, how entries start, and alerts.',
    route: AppRoutes.settings,
    sections: [
      GuideSection('What you can change', [
        'Language switches between English and Bangla at any time, with Bengali digits in Bangla.',
        'Theme follows the phone, or stays light or dark.',
        'Amount entry chooses a plain number keyboard or the calculator keypad for new transactions.',
        'Default account is the wallet a new transaction starts with. Week starts on decides what "this week" means.',
        'Text size makes the letters bigger or smaller, on top of your phone\'s own setting.',
        'Hide balances shows dots instead of your balances on Home and on Accounts when someone is looking. The eye on Home does the same.',
        'Hide income shows dots instead of every income amount: in Transactions, Reports, trips, repeating entries and Month wrapped. Where it can, a bar says how much of the income is spent, which only you will understand. Tap the dots to see the amount for five seconds. Hide balances too, because a balance can give the income away.',
        'Fun mode and the Alerts section are here too.',
      ]),
      GuideSection('Your data', [
        'Remind me to back up shows a card on Home after two weeks without a backup.',
        'Delete all data empties the app like a new install. Export a backup first if you may want anything back.',
        'Open-source licenses lists the libraries the app is built with.',
      ]),
    ],
  ),
  GuideTopic(
    id: 'faq',
    icon: Icons.help_outline,
    group: 'questions',
    title: 'Questions and words',
    summary: 'Quick answers to the things people wonder about.',
    sections: [
      GuideSection('Why does…', [
        'Why is an account in red? It holds less than nothing. An entry is probably missing or sits on the wrong wallet. Add it, or use Adjust balance.',
        'Why is a loan not in my expenses? Lending money is not spending it. Loans and investment capital stay out of income and expense on purpose.',
        'Why is my total different from my wallet? Some account may be marked Not in total, or an entry is missing. Use Adjust balance to match the real money.',
        'Can I use it without the internet? Yes. Only the price fetch in Zakat and Gold & silver needs it, and you can type the price instead.',
      ]),
      GuideSection('Words used in Hishab', [
        'Dhar and baki: money lent and money borrowed.',
        'Kacha bazar: the market for vegetables, fish and meat.',
        'Bhori, ana and roti: the traditional weights for gold. 1 bhori is 16 ana, and 1 ana is 6 roti.',
        'Nisab: the least wealth on which zakat is due.',
        'Salami and fitra: Eid gifts to children and the charity given before Eid prayer.',
      ]),
    ],
  ),
];
