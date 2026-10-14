import 'package:hishab/core/database/app_database.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';

/// What is remembered for the zakat calculator, in the settings table.
class ZakatSettings {
  const ZakatSettings({
    this.basis = NisabBasis.silver,
    this.gramPrice,
    this.otherAssets = 0,
    this.excludedAccountIds = const {},
    this.countOwedToYou = true,
    this.subtractDebts = true,
    this.countMetals = true,
    this.remindMonth,
    this.remindDay,
  });

  static const defaults = ZakatSettings();

  final NisabBasis basis;

  /// The price of a gram of [basis], in poisha.
  final int? gramPrice;

  /// Gold, silver and other savings kept outside the accounts, in poisha.
  final int otherAssets;

  /// The accounts left out of the count.
  final Set<int> excludedAccountIds;
  final bool countOwedToYou;
  final bool subtractDebts;

  /// Whether the gold and silver of Gold & silver are counted.
  final bool countMetals;

  /// The yearly zakat day, if a reminder is wanted.
  final int? remindMonth;
  final int? remindDay;

  bool get hasReminder => remindMonth != null && remindDay != null;

  ZakatSettings copyWith({
    NisabBasis? basis,
    int? Function()? gramPrice,
    int? otherAssets,
    Set<int>? excludedAccountIds,
    bool? countOwedToYou,
    bool? subtractDebts,
    bool? countMetals,
    ({int month, int day})? Function()? remindOn,
  }) => ZakatSettings(
    basis: basis ?? this.basis,
    gramPrice: gramPrice == null ? this.gramPrice : gramPrice(),
    otherAssets: otherAssets ?? this.otherAssets,
    excludedAccountIds: excludedAccountIds ?? this.excludedAccountIds,
    countOwedToYou: countOwedToYou ?? this.countOwedToYou,
    subtractDebts: subtractDebts ?? this.subtractDebts,
    countMetals: countMetals ?? this.countMetals,
    remindMonth: remindOn == null ? remindMonth : remindOn()?.month,
    remindDay: remindOn == null ? remindDay : remindOn()?.day,
  );

  static const _basis = 'zakat.basis';
  static const _gramPrice = 'zakat.gram_price';
  static const _other = 'zakat.other_assets';
  static const _excluded = 'zakat.excluded_accounts';
  static const _owedToYou = 'zakat.count_owed_to_you';
  static const _debts = 'zakat.subtract_debts';
  static const _metals = 'zakat.count_metals';
  static const _remind = 'zakat.remind_on';

  /// Reads the settings from the saved key / value pairs; anything missing or
  /// unreadable falls back to its default.
  factory ZakatSettings.fromMap(Map<String, String> map) {
    final remind = (map[_remind] ?? '').split('-');
    final month = remind.length == 2 ? int.tryParse(remind[0]) : null;
    final day = remind.length == 2 ? int.tryParse(remind[1]) : null;
    final validDay =
        month != null &&
        day != null &&
        month >= 1 &&
        month <= 12 &&
        day >= 1 &&
        day <= 31;
    return ZakatSettings(
      basis: NisabBasis.values.asNameMap()[map[_basis]] ?? NisabBasis.silver,
      gramPrice: int.tryParse(map[_gramPrice] ?? ''),
      otherAssets: int.tryParse(map[_other] ?? '') ?? 0,
      excludedAccountIds: {
        for (final part in (map[_excluded] ?? '').split(','))
          if (int.tryParse(part) != null) int.parse(part),
      },
      countOwedToYou: map[_owedToYou] != 'false',
      subtractDebts: map[_debts] != 'false',
      countMetals: map[_metals] != 'false',
      remindMonth: validDay ? month : null,
      remindDay: validDay ? day : null,
    );
  }

  /// The key / value pairs to save. A null value removes the key.
  Map<String, String?> toMap() => {
    _basis: basis.name,
    _gramPrice: gramPrice?.toString(),
    _other: otherAssets == 0 ? null : '$otherAssets',
    _excluded: excludedAccountIds.isEmpty
        ? null
        : (excludedAccountIds.toList()..sort()).join(','),
    _owedToYou: countOwedToYou ? null : 'false',
    _debts: subtractDebts ? null : 'false',
    _metals: countMetals ? null : 'false',
    _remind: hasReminder ? '$remindMonth-$remindDay' : null,
  };
}

class ZakatSettingsRepository {
  ZakatSettingsRepository(this._db);

  final AppDatabase _db;

  Stream<ZakatSettings> watch() =>
      _db.settingsDao.watchAll().map(ZakatSettings.fromMap);

  Future<ZakatSettings> load() async =>
      ZakatSettings.fromMap(await _db.settingsDao.getAll());

  Future<void> save(ZakatSettings settings) {
    return _db.transaction(() async {
      for (final entry in settings.toMap().entries) {
        await _db.settingsDao.put(entry.key, entry.value);
      }
    });
  }
}
