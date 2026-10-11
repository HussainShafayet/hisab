import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Reports',
      icon: Icons.bar_chart_outlined,
      message: 'Coming in Milestone 6.',
    );
  }
}
