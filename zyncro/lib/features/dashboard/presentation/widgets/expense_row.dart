import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class ExpenseRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const ExpenseRow({
    super.key,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
