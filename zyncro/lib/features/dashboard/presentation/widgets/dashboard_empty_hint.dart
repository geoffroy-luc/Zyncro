import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class DashboardEmptyHint extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const DashboardEmptyHint({
    super.key,
    required this.label,
    required this.onTap,
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
        TextButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Ajouter'),
        ),
      ],
    );
  }
}
