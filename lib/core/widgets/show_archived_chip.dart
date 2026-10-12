import 'package:flutter/material.dart';

/// A chip that turns "show archived" on and off. Archived accounts and
/// categories are hidden, not deleted, so old transactions keep their names;
/// this brings them back into the list (greyed out) so they can be restored.
class ShowArchivedChip extends StatelessWidget {
  const ShowArchivedChip({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FilterChip(
        key: const ValueKey('show-archived'),
        avatar: const Icon(Icons.inventory_2_outlined, size: 18),
        label: const Text('Show archived'),
        selected: value,
        onSelected: onChanged,
      ),
    );
  }
}
