import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/features/metals/domain/metals.dart';

/// What the sheet gives back when a piece is saved.
class HoldingDraft {
  const HoldingDraft({
    required this.metal,
    required this.name,
    required this.milligrams,
    required this.purity,
    this.cost,
  });

  final Metal metal;
  final String name;
  final int milligrams;
  final int purity;
  final int? cost;
}

/// What the sheet gives back: a piece to save, or a wish to delete the one
/// that was being edited.
class HoldingSheetResult {
  const HoldingSheetResult.save(HoldingDraft this.draft) : delete = false;
  const HoldingSheetResult.delete() : draft = null, delete = true;

  final HoldingDraft? draft;
  final bool delete;
}

/// Asks for a piece of gold or silver: what it is, its weight (in bhori, ana
/// and roti or in grams), how pure it is and, if known, what it cost.
Future<HoldingSheetResult?> showHoldingSheet(
  BuildContext context, {
  required GramPrices prices,
  MetalHolding? existing,
}) => showModalBottomSheet<HoldingSheetResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => _HoldingSheet(prices: prices, existing: existing),
);

enum _WeightMode { bhori, gram }

class _HoldingSheet extends StatefulWidget {
  const _HoldingSheet({required this.prices, this.existing});

  final GramPrices prices;
  final MetalHolding? existing;

  @override
  State<_HoldingSheet> createState() => _HoldingSheetState();
}

class _HoldingSheetState extends State<_HoldingSheet> {
  final _name = TextEditingController();
  final _bhori = TextEditingController();
  final _ana = TextEditingController();
  final _roti = TextEditingController();
  final _gram = TextEditingController();
  final _cost = TextEditingController();

  Metal _metal = Metal.gold;
  int _purity = 917;
  _WeightMode _mode = _WeightMode.bhori;
  String? _error;

  @override
  void initState() {
    super.initState();
    final piece = widget.existing;
    if (piece != null) {
      _metal = piece.metal;
      _purity = piece.purity;
      _name.text = piece.name;
      final w = bhoriWeightOf(piece.milligrams);
      _bhori.text = w.bhori == 0 ? '' : '${w.bhori}';
      _ana.text = w.ana == 0 ? '' : '${w.ana}';
      _roti.text = w.roti == 0 ? '' : '${w.roti}';
      _gram.text = (piece.milligrams / 1000).toStringAsFixed(2);
      final cost = piece.cost;
      _cost.text = cost == null ? '' : poishaToInput(cost);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _bhori, _ana, _roti, _gram, _cost]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The weight typed, in milligrams; zero while nothing usable is typed.
  int get _milligrams {
    if (_mode == _WeightMode.bhori) {
      return milligramsFromBhori(
        bhori: int.tryParse(_bhori.text.trim()) ?? 0,
        ana: int.tryParse(_ana.text.trim()) ?? 0,
        roti: int.tryParse(_roti.text.trim()) ?? 0,
      );
    }
    final grams = double.tryParse(_gram.text.trim().replaceAll(',', ''));
    return grams == null || grams <= 0 ? 0 : (grams * 1000).round();
  }

  void _setMetal(Metal metal) => setState(() {
    _metal = metal;
    _purity = quotedPurity(metal);
    _error = null;
  });

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = tr('Give the piece a name, like "Necklace".'));
      return;
    }
    final milligrams = _milligrams;
    if (milligrams <= 0) {
      setState(() => _error = tr('Enter the weight of the piece.'));
      return;
    }
    int? cost;
    if (_cost.text.trim().isNotEmpty) {
      cost = parseTakaToPoisha(_cost.text);
      if (cost == null || cost < 0) {
        setState(
          () => _error = tr('Enter a valid price, like 150000 or 150000.50.'),
        );
        return;
      }
    }
    Navigator.pop(
      context,
      HoldingSheetResult.save(
        HoldingDraft(
          metal: _metal,
          name: name,
          milligrams: milligrams,
          purity: _purity,
          cost: cost,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr('Delete this piece?')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('Cancel')),
          ),
          TextButton(
            key: const ValueKey('holding-confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('Delete')),
          ),
        ],
      ),
    );
    if (sure == true && mounted) {
      Navigator.pop(context, const HoldingSheetResult.delete());
    }
  }

  Widget _number(String key, TextEditingController c, String label) => Expanded(
    child: TextField(
      key: ValueKey(key),
      controller: c,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => setState(() => _error = null),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final milligrams = _milligrams;
    final price = widget.prices.of(_metal);
    final value = milligrams > 0 && price != null
        ? holdingValue(
            milligrams: milligrams,
            purity: _purity,
            gramPrice: price,
          )
        : null;
    const picks = ['Necklace', 'Ring', 'Bangles', 'Earrings', 'Coin', 'Bar'];
    String pickLabel(String pick) => switch (pick) {
      'Necklace' => tr('Necklace'),
      'Ring' => tr('Ring'),
      'Bangles' => tr('Bangles'),
      'Earrings' => tr('Earrings'),
      'Coin' => tr('Coin'),
      _ => tr('Bar'),
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.existing == null ? tr('Add piece') : tr('Edit piece'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const ValueKey('holding-gold'),
                  showCheckmark: false,
                  label: Text(tr('Gold')),
                  selected: _metal == Metal.gold,
                  onSelected: (_) => _setMetal(Metal.gold),
                ),
                ChoiceChip(
                  key: const ValueKey('holding-silver'),
                  showCheckmark: false,
                  label: Text(tr('Silver')),
                  selected: _metal == Metal.silver,
                  onSelected: (_) => _setMetal(Metal.silver),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('holding-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tr('Name')),
              onChanged: (_) => setState(() => _error = null),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final pick in picks)
                  ActionChip(
                    label: Text(pickLabel(pick)),
                    onPressed: () => setState(() {
                      _name.text = pickLabel(pick);
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(tr('How pure is it?'), style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final p in puritiesOf(_metal))
                  ChoiceChip(
                    key: ValueKey('purity-${p.perMille}'),
                    showCheckmark: false,
                    label: Text(purityLabel(_metal, p.perMille)),
                    selected: _purity == p.perMille,
                    onSelected: (_) => setState(() => _purity = p.perMille),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(tr('Weight'), style: theme.textTheme.titleSmall),
                ),
                SegmentedButton<_WeightMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: _WeightMode.bhori,
                      label: Text(tr('Bhori')),
                    ),
                    ButtonSegment(
                      value: _WeightMode.gram,
                      label: Text(tr('Gram')),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() => _mode = s.first),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_mode == _WeightMode.bhori)
              Row(
                children: [
                  _number('holding-bhori', _bhori, tr('Bhori')),
                  const SizedBox(width: 8),
                  _number('holding-ana', _ana, tr('Ana')),
                  const SizedBox(width: 8),
                  _number('holding-roti', _roti, tr('Roti')),
                ],
              )
            else
              TextField(
                key: const ValueKey('holding-gram'),
                controller: _gram,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(labelText: tr('Grams')),
                onChanged: (_) => setState(() => _error = null),
              ),
            if (milligrams > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  [
                    gramText(milligrams),
                    bhoriText(milligrams),
                    if (value != null)
                      tr('Worth about {amount}', {
                        'amount': formatPoisha(value),
                      }),
                  ].join(' · '),
                  key: const ValueKey('holding-preview'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            MoneyFormField(
              key: const ValueKey('holding-cost'),
              controller: _cost,
              label: tr('Price paid (optional)'),
              isRequired: false,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const ValueKey('holding-error'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.existing != null)
                  TextButton(
                    key: const ValueKey('holding-delete'),
                    onPressed: _confirmDelete,
                    child: Text(tr('Delete')),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('Cancel')),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('holding-save'),
                  onPressed: _save,
                  child: Text(tr('Save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
