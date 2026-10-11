import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Home',
      icon: Icons.home_outlined,
      message: 'Coming in Milestone 6.',
    );
  }
}
