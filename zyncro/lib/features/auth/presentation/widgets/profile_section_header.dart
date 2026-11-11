import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

class ProfileSectionHeader extends StatelessWidget {
  final String label;
  const ProfileSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
