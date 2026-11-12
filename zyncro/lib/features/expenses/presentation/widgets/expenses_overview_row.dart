import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class ExpensesOverviewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const ExpensesOverviewRow({
    super.key,
    required this.label,
    required this.value,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            fontSize: bold ? 17 : 14,
          ),
        ),
      ],
    );
  }
}
