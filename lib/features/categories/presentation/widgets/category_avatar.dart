import 'package:flutter/material.dart';
import 'package:hishab/features/categories/presentation/category_style.dart';

/// A category's icon on a circle of its color.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({
    required this.icon,
    required this.color,
    this.radius = 20,
    super.key,
  });

  /// Icon key, see `categoryIcons`.
  final String icon;

  /// ARGB value.
  final int color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final background = Color(color);
    final foreground =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Icon(categoryIconFor(icon), color: foreground, size: radius * 1.1),
    );
  }
}
