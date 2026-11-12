import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/widgets/gradient_circle_button.dart';

/// Barre de saisie en mode enregistrement vocal : annuler, durée, envoyer.
class RecordingBar extends StatelessWidget {
  const RecordingBar({
    super.key,
    required this.elapsed,
    required this.onCancel,
    required this.onSend,
  });

  /// Durée déjà formatée (mm:ss).
  final String elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onCancel,
          child: Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: 12, bottom: 2),
            decoration: BoxDecoration(
              color: context.colors.background,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
            child: const Icon(Icons.close, color: Colors.red, size: 18),
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                elapsed,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.chatEnregistrement,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GradientCircleButton(
          onTap: onSend,
          child: const Icon(Icons.check, color: Colors.white, size: 22),
        ),
      ],
    );
  }
}
