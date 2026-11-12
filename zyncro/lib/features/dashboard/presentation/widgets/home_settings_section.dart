import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Section widget ────────────────────────────────────────────────────────────

class HomeSettingsSection extends StatelessWidget {
  final String title;
  final Widget child;

  const HomeSettingsSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
