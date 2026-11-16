import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';

/// Champ de recherche de la liste des dépenses (dans l'onglet « Dépenses »,
/// au-dessus de la liste : il glisse avec elle, et n'apparaît pas sur
/// « Équilibre »).
class ExpenseSearchField extends StatelessWidget {
  static const fieldKey = Key('expense-search');

  const ExpenseSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search,
              color: context.colors.textSecondary,
              size: 20,
            ),
          ),
          Expanded(
            child: TextField(
              key: fieldKey,
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: context.l10n.expensesRechercherUneDepense,
                hintStyle: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                filled: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
