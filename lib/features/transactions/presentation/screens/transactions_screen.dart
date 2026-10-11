import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Transactions',
      icon: Icons.receipt_long_outlined,
      message: 'Coming in Milestone 4.',
    );
  }
}
