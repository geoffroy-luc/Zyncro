import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

/// Barre de recherche dans les messages (au-dessus de la liste).
class ChatSearchBar extends StatelessWidget {
  const ChatSearchBar({
    super.key,
    required this.onChanged,
    required this.onClose,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(
                      Icons.search,
                      color: context.colors.textSecondary,
                      size: 18,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        hintText: context.l10n.chatRechercherDansLeChat,
                        hintStyle: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: false,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onClose,
            child: Icon(
              Icons.close,
              color: context.colors.textSecondary,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}
