import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hishab/core/l10n/translator.dart';
import 'package:hishab/core/utils/clock.dart';
import 'package:hishab/core/utils/dates.dart';
import 'package:hishab/core/utils/money.dart';
import 'package:hishab/core/utils/validation_exception.dart';
import 'package:hishab/core/widgets/money_form_field.dart';
import 'package:hishab/core/widgets/state_views.dart';
import 'package:hishab/features/categories/domain/category.dart';
import 'package:hishab/features/categories/domain/category_tree.dart';
import 'package:hishab/features/categories/domain/category_type.dart';
import 'package:hishab/features/categories/presentation/providers/categories_providers.dart';
import 'package:hishab/features/challenges/domain/challenge.dart';
import 'package:hishab/features/challenges/presentation/providers/challenges_providers.dart';
import 'package:hishab/features/debts/presentation/widgets/day_field.dart';

/// The lengths offered as buttons, in days.
const _lengths = [3, 7, 14, 30];

/// Starts a spending challenge, or changes one.
class ChallengeFormScreen extends ConsumerWidget {
  const ChallengeFormScreen({this.challengeId, super.key});

  /// Null to start a new one.
  final int? challengeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = challengeId;
    if (id == null) return const _ChallengeForm();

    final items = ref.watch(challengesProvider);
    return items.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(message: describeError(error)),
      ),
      data: (list) {
        final found = list.where((i) => i.challenge.id == id).firstOrNull;
        if (found == null) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorView(message: tr('Challenge not found.')),
          );
        }
        return _ChallengeForm(initial: found.challenge);
      },
    );
  }
}

class _ChallengeForm extends ConsumerStatefulWidget {
  const _ChallengeForm({this.initial});

  final Challenge? initial;

  @override
  ConsumerState<_ChallengeForm> createState() => _ChallengeFormState();
}

class _ChallengeFormState extends ConsumerState<_ChallengeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _limit = TextEditingController(
    text: (widget.initial?.limit ?? 0) > 0
        ? poishaToInput(widget.initial!.limit)
        : '',
  );
  late ChallengeKind _kind = widget.initial?.kind ?? ChallengeKind.noSpend;
  late int? _categoryId = widget.initial?.categoryId;
  late DateTime _start =
      widget.initial?.startDate ?? dateOnly(ref.read(clockProvider)());
  late DateTime _end =
      widget.initial?.endDate ??
      DateTime(_start.year, _start.month, _start.day + 6);

  /// Once the person types a name, it is no longer made from the choices.
  late bool _titleEdited = widget.initial != null;
  late bool _repeats = widget.initial?.repeats ?? false;
  bool _saving = false;
  String? _error;
  List<({int id, String label, String name})> _choices = const [];

  bool get _isEditing => widget.initial != null;

  int get _days => daysBetween(_start, _end) + 1;

  @override
  void initState() {
    super.initState();
    if (!_titleEdited) _title.text = _suggestedTitle();
  }

  @override
  void dispose() {
    _title.dispose();
    _limit.dispose();
    super.dispose();
  }

  String? get _categoryName =>
      _choices.where((c) => c.id == _categoryId).firstOrNull?.name;

  String _suggestedTitle() => challengeTitle(
    kind: _kind,
    days: _days < 1 ? 1 : _days,
    limit: parseTakaToPoisha(_limit.text) ?? 0,
    categoryName: _categoryId == null ? null : _categoryName,
  );

  /// Something changed: update the name made from the choices, unless the
  /// person has written their own.
  void _changed(VoidCallback change) {
    setState(() {
      change();
      _error = null;
      if (!_titleEdited) _title.text = _suggestedTitle();
    });
  }

  /// Fills the form from a preset: a no-spend challenge, with its dates and
  /// category, and a name made for it.
  void _usePreset(ChallengePreset preset, int? categoryId) {
    _titleEdited = false;
    _changed(() {
      _kind = ChallengeKind.noSpend;
      _categoryId = categoryId;
      _start = preset.start;
      _end = DateTime(
        preset.start.year,
        preset.start.month,
        preset.start.day + preset.days - 1,
      );
    });
  }

  Future<void> _pickStart() async {
    final today = dateOnly(ref.read(clockProvider)());
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2),
    );
    if (picked == null || !mounted) return;
    final length = _days;
    _changed(() {
      _start = dateOnly(picked);
      // The challenge keeps its length when it is moved.
      _end = DateTime(_start.year, _start.month, _start.day + length - 1);
    });
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end.isBefore(_start) ? _start : _end,
      firstDate: _start,
      lastDate: DateTime(
        _start.year,
        _start.month,
        _start.day + maxChallengeDays,
      ),
    );
    if (picked != null && mounted) _changed(() => _end = dateOnly(picked));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final repository = ref.read(challengesRepositoryProvider);
    final limit = _kind == ChallengeKind.limit
        ? (parseTakaToPoisha(_limit.text) ?? 0)
        : 0;
    try {
      if (_isEditing) {
        await repository.update(
          widget.initial!.id,
          title: _title.text,
          kind: _kind,
          startDate: _start,
          endDate: _end,
          limit: limit,
          categoryId: _categoryId,
          repeats: _repeats,
        );
      } else {
        await repository.create(
          title: _title.text,
          kind: _kind,
          startDate: _start,
          endDate: _end,
          limit: limit,
          categoryId: _categoryId,
          repeats: _repeats,
        );
      }
      if (mounted) context.pop();
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _error = describeError(e);
          _saving = false;
        });
      }
    }
  }

  /// The category called [name] (ignoring case), if there is one.
  ({int id, String label, String name})? _choiceNamed(String name) => _choices
      .where((c) => c.name.toLowerCase() == name.toLowerCase())
      .firstOrNull;

  /// The expense categories, each followed by what is inside it, labelled with
  /// the whole path (`Food › Fish`).
  List<({int id, String label, String name})> _categoryChoices(
    List<Category> all,
  ) {
    final byId = {for (final c in all) c.id: c};
    return [
      for (final c in flattenCategoryTree(
        buildCategoryTree(all.where((c) => c.type == CategoryType.expense)),
      ))
        (id: c.id, label: categoryPathLabel(c, byId), name: c.name),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Archived categories are not offered, except the one the challenge
    // already has.
    final categories = ref.watch(categoriesProvider(true)).value;
    if (categories != null) {
      _choices = _categoryChoices([
        for (final c in categories)
          if (!c.isArchived || c.id == _categoryId) c,
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Edit challenge') : tr('New challenge')),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (!_isEditing) ...[
                    Text(tr('Quick start'), style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final preset in challengePresets(
                          dateOnly(ref.read(clockProvider)()),
                        ))
                          // A preset about a category needs that category.
                          if (preset.categoryName == null ||
                              _choiceNamed(preset.categoryName!) != null)
                            ActionChip(
                              key: ValueKey('preset-${preset.id.name}'),
                              label: Text(preset.label),
                              onPressed: () => _usePreset(
                                preset,
                                preset.categoryName == null
                                    ? null
                                    : _choiceNamed(preset.categoryName!)?.id,
                              ),
                            ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  SegmentedButton<ChallengeKind>(
                    key: const ValueKey('challenge-kind'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ChallengeKind.noSpend,
                        label: Text(
                          tr('Spend nothing'),
                          key: const ValueKey('kind-noSpend'),
                        ),
                      ),
                      ButtonSegment(
                        value: ChallengeKind.limit,
                        label: Text(
                          tr('Stay under a limit'),
                          key: const ValueKey('kind-limit'),
                        ),
                      ),
                    ],
                    selected: {_kind},
                    onSelectionChanged: (value) =>
                        _changed(() => _kind = value.single),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    key: const ValueKey('challenge-category'),
                    initialValue: _choices.any((c) => c.id == _categoryId)
                        ? _categoryId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('What it is about'),
                      helperText: tr(
                        'A category counts what is inside it too.',
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(tr('All spending')),
                      ),
                      for (final choice in _choices)
                        DropdownMenuItem<int?>(
                          value: choice.id,
                          child: Text(choice.label),
                        ),
                    ],
                    onChanged: (value) => _changed(() => _categoryId = value),
                  ),
                  if (_kind == ChallengeKind.limit) ...[
                    const SizedBox(height: 16),
                    MoneyFormField(
                      key: const ValueKey('challenge-limit'),
                      controller: _limit,
                      label: tr('Spend at most'),
                      onChanged: (_) => _changed(() {}),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(tr('How long'), style: theme.textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in _lengths)
                        ChoiceChip(
                          key: ValueKey('length-$n'),
                          label: Text(plural(n, '1 day', '{n} days')),
                          selected: _days == n,
                          onSelected: (_) => _changed(
                            () => _end = DateTime(
                              _start.year,
                              _start.month,
                              _start.day + n - 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DayField(
                    key: const ValueKey('challenge-start'),
                    label: tr('Starts on'),
                    value: _start,
                    onPick: _pickStart,
                  ),
                  const SizedBox(height: 12),
                  DayField(
                    key: const ValueKey('challenge-end'),
                    label: tr('Ends on'),
                    value: _end,
                    onPick: _pickEnd,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    key: const ValueKey('challenge-repeats'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(tr('Start again when it ends')),
                    subtitle: Text(
                      tr('The same challenge, for the same number of days.'),
                    ),
                    value: _repeats,
                    onChanged: (value) => setState(() => _repeats = value),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    key: const ValueKey('challenge-title'),
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(maxChallengeTitleLength),
                    ],
                    decoration: InputDecoration(labelText: tr('Name')),
                    onChanged: (_) => _titleEdited = true,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? tr('Enter a name')
                        : null,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const ValueKey('form-error'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const ValueKey('challenge-save'),
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _isEditing ? tr('Save changes') : tr('Start challenge'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
