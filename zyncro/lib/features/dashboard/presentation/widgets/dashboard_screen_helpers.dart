import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/design_system/tokens/brand_palette.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';

const dashboardDefaultTabColors = TabPalette.colors;

Color dashboardColorForTab(int idx, TabSettings settings) {
  final hex = switch (idx) {
    0 => settings.homeThemeColor,
    1 => settings.calendarThemeColor,
    2 => settings.notesThemeColor,
    3 => settings.expensesThemeColor,
    4 => settings.chatThemeColor,
    _ => null,
  };
  if (hex == null) return dashboardDefaultTabColors[idx];
  return hexToColor(hex);
}

bool dashboardIsToday(DateTime dt) {
  final now = DateTime.now();
  return dt.year == now.year && dt.month == now.month && dt.day == now.day;
}

String dashboardFormatAmount(double v) => NumberFormat.currency(
  locale: 'fr_FR',
  symbol: '€',
  decimalDigits: 2,
).format(v);

String dashboardTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return 'Il y a ${diff.inDays} j';
}
