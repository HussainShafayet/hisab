import 'package:flutter/material.dart';
import 'package:hishab/core/widgets/state_views.dart';

/// Temporary screen for features that are built in a later milestone.
/// Each feature replaces its placeholder with the real screen.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
    super.key,
  });

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(icon: icon, title: title, message: message),
    );
  }
}
