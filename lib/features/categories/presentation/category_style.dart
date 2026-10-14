import 'package:flutter/material.dart';

/// Icons a category can use, by the key saved in the database. The seeded
/// categories and the "Balance adjustment" category only use keys from here
/// (a test checks it).
const categoryIcons = <String, IconData>{
  'category': Icons.category,
  'restaurant': Icons.restaurant,
  'fastfood': Icons.fastfood,
  'local_cafe': Icons.local_cafe,
  'local_grocery_store': Icons.local_grocery_store,
  'shopping_cart': Icons.shopping_cart,
  'shopping_bag': Icons.shopping_bag,
  'checkroom': Icons.checkroom,
  'directions_bus': Icons.directions_bus,
  'directions_car': Icons.directions_car,
  'two_wheeler': Icons.two_wheeler,
  'local_taxi': Icons.local_taxi,
  'local_gas_station': Icons.local_gas_station,
  'train': Icons.train,
  'flight': Icons.flight,
  'receipt_long': Icons.receipt_long,
  'bolt': Icons.bolt,
  'water_drop': Icons.water_drop,
  'local_fire_department': Icons.local_fire_department,
  'wifi': Icons.wifi,
  'phone_android': Icons.phone_android,
  'home': Icons.home,
  'handyman': Icons.handyman,
  'local_hospital': Icons.local_hospital,
  'medical_services': Icons.medical_services,
  'fitness_center': Icons.fitness_center,
  'spa': Icons.spa,
  'school': Icons.school,
  'menu_book': Icons.menu_book,
  'child_care': Icons.child_care,
  'pets': Icons.pets,
  'card_giftcard': Icons.card_giftcard,
  'celebration': Icons.celebration,
  'movie': Icons.movie,
  'sports_esports': Icons.sports_esports,
  'music_note': Icons.music_note,
  'volunteer_activism': Icons.volunteer_activism,
  'account_balance': Icons.account_balance,
  'payments': Icons.payments,
  'wallet': Icons.wallet,
  'work': Icons.work,
  'store': Icons.store,
  'laptop_mac': Icons.laptop_mac,
  'trending_up': Icons.trending_up,
  'redeem': Icons.redeem,
  'tune': Icons.tune,
  'more_horiz': Icons.more_horiz,
};

IconData categoryIconFor(String key) => categoryIcons[key] ?? Icons.category;

/// Colors a category can use (ARGB). Includes every seeded color.
const categoryColors = <int>[
  0xFFEF5350,
  0xFFEC407A,
  0xFFAB47BC,
  0xFF7E57C2,
  0xFF5C6BC0,
  0xFF42A5F5,
  0xFF29B6F6,
  0xFF26C6DA,
  0xFF26A69A,
  0xFF66BB6A,
  0xFF9CCC65,
  0xFFFFA726,
  0xFFFF7043,
  0xFF8D6E63,
  0xFF78909C,
  0xFF9E9E9E,
  0xFFD81B60,
  0xFF6D4C41,
  0xFF43A047,
  0xFF7CB342,
];

/// Color used for a brand-new category.
const defaultCategoryColor = 0xFF26A69A;
