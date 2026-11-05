/// The parts of Home the person can put away. The cards at the very top (the
/// total balance, what needs doing) and this month's summary always stay.
enum HomeSection {
  /// The row of quick buttons.
  shortcuts,

  /// "Safe to spend today".
  safeToSpend,

  /// The loans, challenge, investments and festival cards.
  plans,

  /// The biggest spending categories.
  topSpending,

  /// The latest transactions.
  recent,

  /// The closed section with Takka, the streak, regret and insights.
  extras,
}

/// The sections that were put away, from the saved text (names, comma
/// separated). Anything unknown is ignored.
Set<HomeSection> parseHiddenSections(String? saved) {
  final names = (saved ?? '').split(',');
  return {
    for (final section in HomeSection.values)
      if (names.contains(section.name)) section,
  };
}

String encodeHiddenSections(Set<HomeSection> hidden) => [
  for (final s in HomeSection.values)
    if (hidden.contains(s)) s.name,
].join(',');

/// [hidden] with [section] put away or brought back.
Set<HomeSection> withSectionHidden(
  Set<HomeSection> hidden,
  HomeSection section, {
  required bool away,
}) {
  final result = {...hidden};
  if (away) {
    result.add(section);
  } else {
    result.remove(section);
  }
  return result;
}
