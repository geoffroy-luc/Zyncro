import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

class TypingIndicator extends StatelessWidget {
  final List<String> typingUsers;

  const TypingIndicator({super.key, required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();

    final String label;
    if (typingUsers.length == 1) {
      label = '${typingUsers[0]} est en train d\'écrire...';
    } else if (typingUsers.length == 2) {
      label =
          '${typingUsers[0]} et ${typingUsers[1]} sont en train d\'écrire...';
    } else {
      label = 'Plusieurs personnes sont en train d\'écrire...';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      color: Colors.white,
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
