import 'package:flutter/material.dart';
import 'package:hishab/core/utils/date_labels.dart';

/// `‹  October 2026  ›`
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
    super.key,
  });

  final DateTime month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Previous month',
          icon: const Icon(Icons.chevron_left),
          onPressed: onPrevious,
        ),
        SizedBox(
          width: 170,
          child: Text(
            monthLabel(month),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          tooltip: 'Next month',
          icon: const Icon(Icons.chevron_right),
          onPressed: canGoNext ? onNext : null,
        ),
      ],
    );
  }
}
