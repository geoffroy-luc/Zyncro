import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/expense_categories.dart';
import '../../../../shared/models/expense_category.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/category_editor_sheet.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/settings_widgets.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';

const _currencies = ['EUR', 'USD', 'GBP', 'CHF', 'JPY', 'CAD', 'AUD'];
const _currencySymbols = {
  'EUR': '€',
  'USD': '\$',
  'GBP': '£',
  'CHF': 'CHF',
  'JPY': '¥',
  'CAD': 'CA\$',
  'AUD': 'A\$',
};

class ExpensesSettingsScreen extends ConsumerStatefulWidget {
  const ExpensesSettingsScreen({super.key});

  @override
  ConsumerState<ExpensesSettingsScreen> createState() =>
      _ExpensesSettingsScreenState();
}

class _ExpensesSettingsScreenState
    extends ConsumerState<ExpensesSettingsScreen> {
  Future<void> _update(TabSettings next) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref.read(tabSettingsRepositoryProvider).updateSettings(groupId, next);
  }

  Future<void> _openCategoryEditor(
    TabSettings settings, {
    ExpenseCategory? existing,
  }) async {
    final result = await showCategoryEditor(context, initial: existing);
    if (result == null) return;
    final categories = [...settings.expensesCategories];
    if (existing != null) {
      final index = categories.indexOf(existing);
      if (index != -1) categories[index] = result;
    } else {
      categories.add(result);
    }
    await _update(settings.copyWith(expensesCategories: categories));
  }

  Future<void> _deleteCategory(TabSettings settings, ExpenseCategory cat) async {
    final updated = settings.expensesCategories
        .where((c) => c != cat)
        .toList();
    await _update(settings.copyWith(expensesCategories: updated));
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Paramètres Dépenses',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: 'Apparence',
            children: [
              SettingsTile(
                title: 'Couleur du thème',
                child: ColorPickerRow(
                  selected: settings.expensesThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) =>
                      _update(settings.copyWith(expensesThemeColor: hex)),
                  onAddColor: (hex) => _update(
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
                  onDeleteColor: (hex) => _update(settings.withColorRemoved(hex)),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Devise',
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: settings.expensesCurrency,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                    items: _currencies
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('$c  ${_currencySymbols[c] ?? ''}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _update(settings.copyWith(expensesCurrency: val));
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Catégories',
            children: [
              for (final cat in settings.expensesCategories)
                Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      onTap: () =>
                          _openCategoryEditor(settings, existing: cat),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: hexToColor(cat.colorHex).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          iconForKey(cat.iconKey),
                          size: 18,
                          color: hexToColor(cat.colorHex),
                        ),
                      ),
                      title: Text(cat.name),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 20,
                        ),
                        onPressed: () => _deleteCategory(settings, cat),
                      ),
                    ),
                    const SettingsDivider(),
                  ],
                ),
              SettingsTile(
                title: 'Ajouter une catégorie',
                trailing: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                showChevron: false,
                onTap: () => _openCategoryEditor(settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
