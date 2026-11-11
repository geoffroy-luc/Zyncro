import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/features/expenses/presentation/widgets/settlement.dart';
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
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return "Aujourd'hui";
  if (diff.inDays == 1) return 'Hier';
  if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
  return DateFormat('d MMM', 'fr_FR').format(dt);
}

List<Settlement> expensesComputeSettlements(Map<String, double> balances) {
  final creditors =
      balances.entries
          .where((e) => e.value > 0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
  final debtors =
      balances.entries
          .where((e) => e.value < -0.01)
          .map((e) => MapEntry(e.key, e.value))
          .toList()
        ..sort((a, b) => a.value.compareTo(b.value));

  final result = <Settlement>[];
  int ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    final credit = creditors[ci].value;
    final debt = debtors[di].value.abs();
    final transfer = min(credit, debt);
    result.add((
      fromUid: debtors[di].key,
      toUid: creditors[ci].key,
      amount: transfer,
    ));
    creditors[ci] = MapEntry(creditors[ci].key, credit - transfer);
    debtors[di] = MapEntry(debtors[di].key, debtors[di].value + transfer);
    if (creditors[ci].value < 0.01) ci++;
    if (debtors[di].value > -0.01) di++;
  }
  return result;
}
