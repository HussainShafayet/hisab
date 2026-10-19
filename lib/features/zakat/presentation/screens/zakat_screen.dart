import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/core/notifications/reminder_scheduler.dart';
import 'package:hishab/core/theme/finance_colors.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/accounts/domain/account.dart';
import 'package:hishab/features/accounts/domain/credit_card.dart';
import 'package:hishab/features/accounts/presentation/providers/accounts_providers.dart';
import 'package:hishab/features/debts/domain/debt.dart';
import 'package:hishab/features/debts/presentation/providers/debts_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';
import 'package:hishab/features/metals/presentation/providers/metals_providers.dart';
import 'package:hishab/features/reminders/reminder_sync.dart';
import 'package:hishab/features/zakat/data/zakat_settings_repository.dart';
import 'package:hishab/features/zakat/domain/zakat.dart';
import 'package:hishab/features/zakat/presentation/providers/zakat_providers.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:intl/intl.dart';

/// A rough zakat calculator: what is held in the accounts and elsewhere, less
/// debts, against the nisab, with a yearly reminder. The price of silver or
/// gold can be typed or fetched from the internet when the person asks.
class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key});

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  final _gram = TextEditingController();
  final _other = TextEditingController();
  bool _loaded = false;
  bool _fetching = false;
  String? _fetchError;
  bool _fetched = false;

  @override
  void dispose() {
    _gram.dispose();
    _other.dispose();
    super.dispose();
  }

  Future<void> _save(ZakatSettings next) =>
      ref.read(zakatSettingsRepositoryProvider).save(next);

  Future<void> _fetchPrice(ZakatSettings settings) async {
    setState(() {
      _fetching = true;
      _fetchError = null;
    });
    try {
      final service = ref.read(rateServiceProvider);
      final rate = await service.usdToBdt();
      final metals = await service.metals();
      final price = gramPriceFrom(
        usdPerOunce: settings.basis == NisabBasis.silver
            ? metals.silverPerOunce
            : metals.goldPerOunce,
        bdtPerUsd: rate,
      );
      _gram.text = poishaToInput(price);
      await _save(settings.copyWith(gramPrice: () => price));
      if (mounted) setState(() => _fetched = true);
    } on RateException catch (e) {
      if (mounted) setState(() => _fetchError = e.message);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _pickReminderDay(ZakatSettings settings) async {
    final today = dateOnly(ref.read(clockProvider)());
    final current = settings.hasReminder
        ? nextZakatDay(settings.remindMonth!, settings.remindDay!, today)
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
    );
    if (picked == null || !mounted) return;
    await _save(
      settings.copyWith(remindOn: () => (month: picked.month, day: picked.day)),
    );
    ref.invalidate(reminderSyncProvider);
    await ref.read(reminderSchedulerProvider).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(zakatSettingsProvider).value;
    final theme = Theme.of(context);
    final colors = context.financeColors;
    final today = ref.watch(clockProvider)();

    if (saved == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Zakat'))),
        body: const LoadingView(),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _gram.text = saved.gramPrice == null
          ? ''
          : poishaToInput(saved.gramPrice!);
      _other.text = saved.otherAssets == 0
          ? ''
          : poishaToInput(saved.otherAssets);
    }
    final settings = saved;

    final accounts =
        ref.watch(accountsProvider(false)).value ??
        const <AccountWithBalance>[];
    // Credit cards are debts, not savings; an account that is overdrawn holds
    // nothing.
    final savings = [
      for (final item in accounts)
        if (!item.account.isCreditCard) item,
    ];
    int counted(AccountWithBalance item) =>
        settings.excludedAccountIds.contains(item.account.id) ||
            item.balance <= 0
        ? 0
        : item.balance;
    final inAccounts = savings.fold(0, (sum, item) => sum + counted(item));

    final debts = ref.watch(debtsProvider).value ?? const <DebtItem>[];
    var owedToYou = 0;
    var borrowed = 0;
    for (final item in debts) {
      if (item.debt.direction == DebtDirection.lent) {
        owedToYou += item.remaining;
      } else {
        borrowed += item.remaining;
      }
    }
    final metals = ref.watch(metalTotalsProvider);
    final metalsValue = settings.countMetals ? metals.value : 0;
    final cardsOwed = totalOwed(ref.watch(creditCardsProvider));
    final debtsTotal = borrowed + cardsOwed;

    final result = calculateZakat(
      ZakatInput(
        accounts: inAccounts,
        owedToYou: settings.countOwedToYou ? owedToYou : 0,
        otherAssets: settings.otherAssets + metalsValue,
        youOwe: settings.subtractDebts ? debtsTotal : 0,
        nisab: nisabValue(settings.basis, settings.gramPrice),
      ),
    );
    final remindDay = settings.hasReminder
        ? nextZakatDay(settings.remindMonth!, settings.remindDay!, today)
        : null;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Zakat')),
        actions: const [HelpButton('zakat')],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              tr(
                'A rough guide, worked out from what is in Hishab. If you are '
                'unsure, ask a scholar.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          heading(tr('What you have')),
          for (final item in savings)
            CheckboxListTile(
              key: ValueKey('zakat-account-${item.account.id}'),
              dense: true,
              value: !settings.excludedAccountIds.contains(item.account.id),
              title: Text(item.account.name),
              secondary: Text(
                formatPoisha(item.balance),
                style: theme.textTheme.bodyMedium?.tabular,
              ),
              onChanged: (on) {
                final next = {...settings.excludedAccountIds};
                on == true
                    ? next.remove(item.account.id)
                    : next.add(item.account.id);
                _save(settings.copyWith(excludedAccountIds: next));
              },
            ),
          SwitchListTile(
            key: const ValueKey('zakat-owed-to-you'),
            dense: true,
            title: Text(tr('Add money others owe you')),
            subtitle: Text(formatPoisha(owedToYou)),
            value: settings.countOwedToYou,
            onChanged: (on) => _save(settings.copyWith(countOwedToYou: on)),
          ),
          if (!metals.isEmpty)
            SwitchListTile(
              key: const ValueKey('zakat-count-metals'),
              dense: true,
              title: Text(tr('Add my gold and silver')),
              subtitle: Text(
                formatPoisha(metals.value),
                key: const ValueKey('zakat-metals-value'),
              ),
              value: settings.countMetals,
              onChanged: (on) => _save(settings.copyWith(countMetals: on)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: MoneyFormField(
              key: const ValueKey('zakat-other'),
              controller: _other,
              label: tr('Other savings (optional)'),
              isRequired: false,
              onChanged: (text) => _save(
                settings.copyWith(otherAssets: parseTakaToPoisha(text) ?? 0),
              ),
            ),
          ),
          heading(tr('What you owe')),
          SwitchListTile(
            key: const ValueKey('zakat-subtract-debts'),
            dense: true,
            title: Text(tr('Take off your debts and card bills')),
            subtitle: Text(formatPoisha(debtsTotal)),
            value: settings.subtractDebts,
            onChanged: (on) => _save(settings.copyWith(subtractDebts: on)),
          ),
          heading(tr('Nisab')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('zakat-silver'),
                  showCheckmark: false,
                  label: Text(tr('Silver (612.36 g)')),
                  selected: settings.basis == NisabBasis.silver,
                  onSelected: (_) => _changeBasis(settings, NisabBasis.silver),
                ),
                ChoiceChip(
                  key: const ValueKey('zakat-gold'),
                  showCheckmark: false,
                  label: Text(tr('Gold (87.48 g)')),
                  selected: settings.basis == NisabBasis.gold,
                  onSelected: (_) => _changeBasis(settings, NisabBasis.gold),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: MoneyFormField(
                    key: const ValueKey('zakat-gram'),
                    controller: _gram,
                    label: tr('Price of one gram'),
                    isRequired: false,
                    onChanged: (text) {
                      setState(() => _fetched = false);
                      final price = parseTakaToPoisha(text);
                      _save(
                        settings.copyWith(
                          gramPrice: () =>
                              price == null || price <= 0 ? null : price,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    key: const ValueKey('zakat-fetch'),
                    onPressed: _fetching ? null : () => _fetchPrice(settings),
                    icon: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(tr('Today\'s price')),
                  ),
                ),
              ],
            ),
          ),
          if (_fetchError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                _fetchError!,
                key: const ValueKey('zakat-fetch-error'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          else if (_fetched)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                tr(
                  'From the market price of the metal. A jeweller\'s price '
                  'may differ.',
                ),
                key: const ValueKey('zakat-fetched'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          heading(tr('Result')),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Line(
                    keyName: 'zakat-assets',
                    label: tr('You have'),
                    value: formatPoisha(result.assets),
                  ),
                  _Line(
                    keyName: 'zakat-liabilities',
                    label: tr('You owe'),
                    value: formatPoisha(result.liabilities),
                  ),
                  _Line(
                    keyName: 'zakat-net',
                    label: tr('Left to count'),
                    value: formatPoisha(result.net),
                    bold: true,
                  ),
                  _Line(
                    keyName: 'zakat-nisab',
                    label: tr('Nisab'),
                    value: result.nisab == null
                        ? '-'
                        : formatPoisha(result.nisab!),
                  ),
                  const Divider(height: 24),
                  if (result.needsNisab)
                    Text(
                      tr('Enter the price of a gram to see if zakat is due.'),
                      key: const ValueKey('zakat-result'),
                    )
                  else if (result.isDue) ...[
                    Text(
                      tr('Zakat due'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatPoisha(result.due),
                      key: const ValueKey('zakat-due'),
                      style: theme.textTheme.headlineSmall?.tabular.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.expense,
                      ),
                    ),
                    Text(
                      tr('2.5% of {amount}', {
                        'amount': formatPoisha(result.net),
                      }),
                      key: const ValueKey('zakat-result'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ] else
                    Text(
                      tr(
                        'Your wealth is {short} under the nisab, so no zakat '
                        'is due.',
                        {'short': formatPoisha(result.shortOfNisab ?? 0)},
                      ),
                      key: const ValueKey('zakat-result'),
                    ),
                ],
              ),
            ),
          ),
          heading(tr('Yearly reminder')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DayField(
              key: const ValueKey('zakat-remind'),
              label: tr('Remind me every year on'),
              value: remindDay,
              onPick: () => _pickReminderDay(settings),
              onClear: () async {
                await _save(settings.copyWith(remindOn: () => null));
                ref.invalidate(reminderSyncProvider);
              },
            ),
          ),
          if (remindDay != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                tr('Next reminder: {date}', {
                  'date': DateFormat('d MMM yyyy').format(remindDay),
                }),
                key: const ValueKey('zakat-next-reminder'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Silver and gold cost differently, so the price of a gram is cleared.
  void _changeBasis(ZakatSettings settings, NisabBasis basis) {
    if (settings.basis == basis) return;
    _gram.clear();
    setState(() => _fetched = false);
    _save(settings.copyWith(basis: basis, gramPrice: () => null));
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.keyName,
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String keyName;
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.tabular
        .copyWith(fontWeight: bold ? FontWeight.w700 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, key: ValueKey(keyName), style: style),
        ],
      ),
    );
  }
}
