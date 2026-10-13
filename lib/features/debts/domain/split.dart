/// One friend's part of a bill that was paid for everyone.
class SplitShare {
  const SplitShare({required this.person, required this.amount});

  final String person;

  /// In poisha, above zero.
  final int amount;
}

/// A bill shared equally between you and [friends] others: what each friend
/// owes and what is left as your own part, all in poisha. The few poisha that
/// do not divide evenly stay with you.
({int mine, int each}) equalSplit(int total, int friends) {
  final each = total ~/ (friends + 1);
  return (mine: total - each * friends, each: each);
}

const maxSplitFriends = 20;
