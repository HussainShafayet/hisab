# Hishab

Offline personal finance tracker (income, expenses, monthly budget). Android only,
no backend, no internet permission. All data lives in a local SQLite database.

## Setup

```sh
export PATH="$HOME/development/flutter/bin:$PATH"   # add to ~/.zshrc
flutter pub get
flutter run                                          # needs an Android device/emulator
```

Checks:

```sh
flutter analyze
flutter test
```

Code generation (run after changing a drift table or DAO; the generated `*.g.dart`
files are kept in the repo so a fresh checkout builds without this step):

```sh
dart run build_runner build --delete-conflicting-outputs
```

## Structure

Feature-first, repository pattern. Each feature has `data/` (tables, DAOs,
repository), `domain/` (models, pure logic) and `presentation/` (screens, widgets,
providers). Shared code is in `lib/core/` (database, router, theme, utils, widgets).
