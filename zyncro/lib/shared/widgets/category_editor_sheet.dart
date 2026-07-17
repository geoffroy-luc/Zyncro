import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/expense_categories.dart';
import '../../core/theme/app_theme.dart';
import '../models/expense_category.dart';
import 'color_picker_row.dart';

Future<ExpenseCategory?> showCategoryEditor(
  BuildContext context, {
  ExpenseCategory? initial,
  Color? accentColor,
}) {
  return showModalBottomSheet<ExpenseCategory>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => accentColor == null
        ? CategoryEditorSheet(initial: initial)
        : Theme(
            data: AppTheme.themed(accentColor),
            child: CategoryEditorSheet(initial: initial),
          ),
  );
}

class CategoryEditorSheet extends StatefulWidget {
  final ExpenseCategory? initial;
  const CategoryEditorSheet({super.key, this.initial});

  @override
  State<CategoryEditorSheet> createState() => _CategoryEditorSheetState();
}

class _CategoryEditorSheetState extends State<CategoryEditorSheet> {
  late final TextEditingController _nameCtrl;
  late String _iconKey;
  late String _colorHex;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initial?.name ?? '');
    _iconKey = widget.initial?.iconKey ?? 'label';
    _colorHex = widget.initial?.colorHex ?? '#4F7CFF';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      ExpenseCategory(name: name, iconKey: _iconKey, colorHex: _colorHex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final color = hexToColor(_colorHex);
    final isEditing = widget.initial != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              isEditing ? 'Modifier la catégorie' : 'Nouvelle catégorie',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameCtrl,
              autofocus: !isEditing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom',
                hintText: 'Ex : Santé, Éducation...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Icône',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: expenseCategoryIcons.entries.map((entry) {
                final selected = _iconKey == entry.key;
                return GestureDetector(
                  onTap: () => setState(() => _iconKey = entry.key),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? color : AppColors.border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      entry.value,
                      size: 18,
                      color: selected ? color : AppColors.textSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Couleur',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            ColorPickerRow(
              selected: _colorHex,
              onSelect: (hex) => setState(() => _colorHex = hex),
              onAddColor: (hex) => setState(() => _colorHex = hex),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(isEditing ? 'Enregistrer' : 'Ajouter'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
