import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Widgets helpers ──────────────────────────────────────────────────────────

class DashboardCard extends StatelessWidget {
  final Widget child;
  const DashboardCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
        boxShadow: [
          BoxShadow(
            color: context.colors.shadow,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
