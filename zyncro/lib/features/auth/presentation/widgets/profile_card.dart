import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class ProfileCard extends StatelessWidget {
  final Widget child;
  const ProfileCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}
