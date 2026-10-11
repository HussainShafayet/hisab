import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Budget',
      icon: Icons.savings_outlined,
      message: 'Coming in Milestone 5.',
    );
  }
}
