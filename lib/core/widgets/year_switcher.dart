import 'package:flutter/material.dart';
import 'package:hishab/core/l10n/translator.dart';

/// `‹  2026  ›`
class YearSwitcher extends StatelessWidget {
  const YearSwitcher({
    required this.year,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final int year;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          key: const ValueKey('year-previous'),
          tooltip: tr('Previous year'),
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SizedBox(
          width: 170,
          child: Text(
            localizeDigits('$year'),
            key: const ValueKey('year-label'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          key: const ValueKey('year-next'),
          tooltip: tr('Next year'),
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
