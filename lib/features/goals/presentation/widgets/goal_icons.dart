import 'package:flutter/material.dart';

/// The icon for a goal's icon key (see `goalIcons`). An unknown key gets the
/// flag.
IconData goalIconData(String key) => switch (key) {
  'laptop' => Icons.laptop_mac,
  'phone' => Icons.smartphone,
  'bike' => Icons.pedal_bike,
  'car' => Icons.directions_car_outlined,
  'home' => Icons.home_outlined,
  'travel' => Icons.flight_takeoff,
  'education' => Icons.school_outlined,
  'wedding' => Icons.favorite_border,
  'gift' => Icons.card_giftcard,
  'health' => Icons.medical_services_outlined,
  'emergency' => Icons.shield_outlined,
  _ => Icons.flag_outlined,
};
