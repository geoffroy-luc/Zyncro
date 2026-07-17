import 'package:flutter/material.dart';

const expenseCategoryIcons = <String, IconData>{
  'restaurant': Icons.restaurant_outlined,
  'home': Icons.home_outlined,
  'car': Icons.directions_car_outlined,
  'games': Icons.sports_esports_outlined,
  'build': Icons.build_outlined,
  'category': Icons.category_outlined,
  'label': Icons.label_outline,
  'shopping': Icons.shopping_bag_outlined,
  'health': Icons.local_hospital_outlined,
  'school': Icons.school_outlined,
  'pets': Icons.pets_outlined,
  'fitness': Icons.fitness_center_outlined,
  'flight': Icons.flight_outlined,
  'movie': Icons.movie_outlined,
  'book': Icons.menu_book_outlined,
  'gift': Icons.card_giftcard_outlined,
  'coffee': Icons.local_cafe_outlined,
  'phone': Icons.phone_iphone_outlined,
  'tools': Icons.handyman_outlined,
  'savings': Icons.savings_outlined,
  'card': Icons.credit_card_outlined,
  'clothes': Icons.checkroom_outlined,
  'spa': Icons.spa_outlined,
  'child': Icons.child_care_outlined,
  'party': Icons.celebration_outlined,
};

IconData iconForKey(String key) => expenseCategoryIcons[key] ?? Icons.label_outline;
