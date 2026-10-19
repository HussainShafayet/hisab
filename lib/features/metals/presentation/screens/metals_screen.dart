import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/net/rate_service.dart';
import 'package:hishab/core/theme/tabular_figures.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/app_snack_bar.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/metals/domain/metals.dart';
import 'package:hishab/features/metals/presentation/providers/metals_providers.dart';
import 'package:hishab/features/metals/presentation/widgets/holding_sheet.dart';
import 'package:hishab/features/help/presentation/widgets/help_button.dart';
import 'package:intl/intl.dart';

const _goldColor = Color(0xFFD4A017);
const _silverColor = Color(0xFF90A4AE);

/// The gold and silver the person keeps, what it is worth today and, with a
/// tap, today's market price from the internet. The price of a bhori can
/// always be typed instead.
class MetalsScreen extends ConsumerStatefulWidget {
  const MetalsScreen({super.key});

  @override
  ConsumerState<MetalsScreen> createState() => _MetalsScreenState();
}

class _MetalsScreenState extends ConsumerState<MetalsScreen> {
  final _gold = TextEditingController();
  final _silver = TextEditingController();
  bool _loaded = false;
  bool _fetching = false;
  bool _fetched = false;
  String? _fetchError;

  @override
  void dispose() {
    _gold.dispose();
    _silver.dispose();
    super.dispose();
  }

  void _showPrices(GramPrices prices) {
    String field(Metal metal) {
      final gram = prices.of(metal);
      return gram == null ? '' : poishaToInput(bhoriPriceFromGram(metal, gram));
    }

    _gold.text = field(Metal.gold);
    _silver.text = field(Metal.silver);
  }

  /// Saves a price of a bhori typed in a field, as the price of a gram.
  Future<void> _typed(Metal metal, String text, GramPrices prices) {
    final bhori = parseTakaToPoisha(text);
    final gram = bhori == null || bhori <= 0
        ? null
        : gramPriceFromBhori(metal, bhori);
    setState(() => _fetched = false);
    return ref
        .read(metalsRepositoryProvider)
        .savePrices(
          metal == Metal.gold
              ? prices.copyWith(gold: () => gram)
              : prices.copyWith(silver: () => gram),
        );
  }

  Future<void> _fetch() async {
    setState(() {
      _fetching = true;
      _fetchError = null;
    });
    try {
      final fetched = await ref
          .read(metalsRepositoryProvider)
          .fetchPrices(ref.read(rateServiceProvider));
      _showPrices(fetched);
      if (mounted) setState(() => _fetched = true);
    } on RateException catch (e) {
      if (mounted) setState(() => _fetchError = e.message);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _edit(GramPrices prices, [MetalHolding? piece]) async {
    final result = await showHoldingSheet(
      context,
      prices: prices,
      existing: piece,
    );
    if (result == null || !mounted) return;
    final repo = ref.read(metalsRepositoryProvider);
    try {
      if (result.delete) {
        await repo.delete(piece!.id);
        return;
      }
      final d = result.draft!;
      if (piece == null) {
        await repo.add(
          metal: d.metal,
          name: d.name,
          milligrams: d.milligrams,
          purity: d.purity,
          cost: d.cost,
        );
      } else {
        await repo.update(
          piece.id,
          metal: d.metal,
          name: d.name,
          milligrams: d.milligrams,
          purity: d.purity,
          cost: d.cost,
        );
      }
    } on Object catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showError(describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final holdings = ref.watch(metalHoldingsProvider).value;
    final savedPrices = ref.watch(gramPricesProvider).value;
    final theme = Theme.of(context);
    final title = Text(tr('Gold & silver'));

    if (holdings == null || savedPrices == null) {
      return Scaffold(
        appBar: AppBar(title: title),
        body: const LoadingView(),
      );
    }
    if (!_loaded) {
      _loaded = true;
      _showPrices(savedPrices);
    }
    final prices = savedPrices;
    final totals = totalsOf(holdings, prices);
    final missingPrice = [
      for (final metal in Metal.values)
        if (totals.of(metal).count > 0 && prices.of(metal) == null) metal,
    ];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    Widget metalLine(Metal metal) {
      final total = totals.of(metal);
      if (total.count == 0) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${metal == Metal.gold ? tr('Gold') : tr('Silver')}: '
          '${plural(total.count, '1 piece', '{n} pieces')} · '
          '${bhoriText(total.milligrams)} · ${gramText(total.milligrams)}',
          key: ValueKey('metals-${metal.name}-line'),
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: title, actions: const [HelpButton('metals')]),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('metals-add'),
        onPressed: () => _edit(prices),
        icon: const Icon(Icons.add),
        label: Text(tr('Add piece')),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Total worth'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    formatPoisha(totals.value),
                    key: const ValueKey('metals-total'),
                    style: theme.textTheme.headlineMedium?.tabular.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  metalLine(Metal.gold),
                  metalLine(Metal.silver),
                  if (missingPrice.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        tr(
                          'Set the price of a bhori below to see what it is '
                          'worth.',
                        ),
                        key: const ValueKey('metals-needs-price'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          heading(tr('Prices')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                MoneyFormField(
                  key: const ValueKey('metals-gold-price'),
                  controller: _gold,
                  label: tr('Price of 1 bhori of gold (22K)'),
                  isRequired: false,
                  onChanged: (text) => _typed(Metal.gold, text, prices),
                ),
                const SizedBox(height: 8),
                MoneyFormField(
                  key: const ValueKey('metals-silver-price'),
                  controller: _silver,
                  label: tr('Price of 1 bhori of silver (pure)'),
                  isRequired: false,
                  onChanged: (text) => _typed(Metal.silver, text, prices),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('metals-fetch'),
                    onPressed: _fetching ? null : _fetch,
                    icon: _fetching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined),
                    label: Text(tr("Today's price")),
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
                key: const ValueKey('metals-fetch-error'),
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
                  'The market price of the metal. A jeweller\'s price is '
                  'usually higher, so type yours if you know it.',
                ),
                key: const ValueKey('metals-fetched'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else if (prices.at != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                tr('Price set on {date}', {
                  'date': DateFormat.yMMMd().format(prices.at!),
                }),
                key: const ValueKey('metals-price-date'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          heading(tr('Your pieces')),
          if (holdings.isEmpty)
            EmptyState(
              icon: Icons.diamond_outlined,
              title: tr('No gold or silver yet'),
              message: tr(
                'Add a necklace, bangle or coin to see what it is worth today.',
              ),
            )
          else
            for (final piece in holdings)
              _PieceTile(
                piece: piece,
                price: prices.of(piece.metal),
                onTap: () => _edit(prices, piece),
              ),
        ],
      ),
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.piece,
    required this.price,
    required this.onTap,
  });

  final MetalHolding piece;
  final int? price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = price == null
        ? null
        : holdingValue(
            milligrams: piece.milligrams,
            purity: piece.purity,
            gramPrice: price!,
          );
    final cost = piece.cost;
    return ListTile(
      key: ValueKey('piece-${piece.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: piece.metal == Metal.gold ? _goldColor : _silverColor,
        child: const Icon(Icons.diamond_outlined, color: Colors.white),
      ),
      title: Text(piece.name),
      subtitle: Text(
        [
          purityLabel(piece.metal, piece.purity),
          bhoriText(piece.milligrams),
          gramText(piece.milligrams),
          if (cost != null)
            tr('Bought for {amount}', {'amount': formatPoisha(cost)}),
        ].join(' · '),
      ),
      trailing: Text(
        value == null ? '-' : formatPoisha(value),
        style: theme.textTheme.titleSmall?.tabular,
      ),
    );
  }
}
