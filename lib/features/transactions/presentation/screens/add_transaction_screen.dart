import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class AddTransactionScreen extends StatelessWidget {
  const AddTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Add transaction',
      icon: Icons.add_card_outlined,
      message: 'Coming in Milestone 4.',
    );
  }
}
