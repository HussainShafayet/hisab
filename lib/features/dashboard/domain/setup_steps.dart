/// The first things worth doing in Hishab, in the order to do them.
enum SetupStep {
  /// Write the first entry.
  firstEntry,

  /// Set the budget of the month.
  budget,

  /// Make a first backup.
  backup,

  /// Turn on the backup to Google Drive.
  drive,
}

/// Which steps are done, and how far along the person is.
class SetupProgress {
  const SetupProgress(this.done);

  final Set<SetupStep> done;

  int get doneCount => done.length;
  int get total => SetupStep.values.length;
  bool get isComplete => done.length == total;

  /// The next step to do, or null when all are done.
  SetupStep? get next {
    for (final step in SetupStep.values) {
      if (!done.contains(step)) return step;
    }
    return null;
  }
}

/// Works out the [SetupProgress] from what exists.
SetupProgress setupProgressOf({
  required bool hasEntry,
  required bool hasBudget,
  required bool hasBackup,
  required bool driveOn,
}) => SetupProgress({
  if (hasEntry) SetupStep.firstEntry,
  if (hasBudget) SetupStep.budget,
  if (hasBackup) SetupStep.backup,
  if (driveOn) SetupStep.drive,
});
