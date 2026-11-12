import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/shared/domain/categories/expense_category.dart';

const expensesCurrencySymbols = {
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'CHF': 'CHF',
  'JPY': '¥',
  'CAD': 'CA\$',
  'AUD': 'A\$',
};

Color expensesCatColor(List<ExpenseCategory> categories, String? cat) {
  for (final c in categories) {
    if (c.name == cat) return hexToColor(c.colorHex);
  }
  return const Color(0xFF6B7280);
}

String expensesFormatAmount(double v, {String currency = 'EUR'}) {
  final symbol = expensesCurrencySymbols[currency] ?? currency;
  final abs = v.abs();
  if (abs >= 1000000) {
    final m = v / 1000000;
    return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1).replaceAll('.', ',')}M $symbol';
  }
  if (abs >= 1000) {
    final k = v / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1).replaceAll('.', ',')}k $symbol';
  }
  return NumberFormat.currency(
    locale: 'fr_FR',
    symbol: symbol,
    decimalDigits: 2,
  ).format(v);
}

String expensesFormatDate(DateTime dt) {
  // BUG E22 corrigé : jours de calendrier (une dépense d'hier à 23 h n'est
  // plus « Aujourd'hui » à 8 h). UTC : pas de journée de 23 h à l'heure d'été.
  final now = DateTime.now();
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(dt.year, dt.month, dt.day)).inDays;
  if (days == 0) return "Aujourd'hui";
  if (days == 1) return 'Hier';
  if (days > 1 && days < 7) return 'Il y a $days j';
  return DateFormat('d MMM', 'fr_FR').format(dt);
}
