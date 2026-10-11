import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/placeholder_screen.dart';

class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderScreen(
      title: 'Backup & export',
      icon: Icons.backup_outlined,
      message: 'Coming in Milestone 7.',
    );
  }
}
