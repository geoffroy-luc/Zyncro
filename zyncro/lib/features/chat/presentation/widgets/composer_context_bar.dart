import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

/// Bandeau au-dessus du champ de saisie (réponse à un message, modification) :
/// filet de couleur, contenu, bouton de fermeture.
class ComposerContextBar extends StatelessWidget {
  const ComposerContextBar({
    super.key,
    required this.child,
    required this.onClose,
  });

  final Widget child;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: context.colors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: context.colors.textSecondary,
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
