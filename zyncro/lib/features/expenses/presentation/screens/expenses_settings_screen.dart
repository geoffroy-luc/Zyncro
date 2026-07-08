import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/tab_settings.dart';
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

  Future<void> _addCategory(TabSettings settings) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Ex : Santé, Éducation...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    final updated = [...settings.expensesCustomCategories, result];
    await _update(settings.copyWith(expensesCustomCategories: updated));
  }

  Future<void> _deleteCategory(TabSettings settings, String cat) async {
    final updated = settings.expensesCustomCategories
        .where((c) => c != cat)
        .toList();
    await _update(settings.copyWith(expensesCustomCategories: updated));
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
        children: [
          SettingsSection(
            title: 'Apparence',
            children: [
              SettingsTile(
                title: 'Couleur du thème',
                child: ColorPickerRow(
                  selected: settings.expensesThemeColor,
                  extraColors: settings.customColors,
                  onSelect: (hex) =>
                      _update(settings.copyWith(expensesThemeColor: hex)),
                  onAddColor: (hex) => _update(
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
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
            title: 'Catégories personnalisées',
            children: [
              if (settings.expensesCustomCategories.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Text(
                    'Aucune catégorie personnalisée.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                )
              else
                ...settings.expensesCustomCategories.map(
                  (cat) => Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        title: Text(cat),
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          onPressed: () => _deleteCategory(settings, cat),
                        ),
                      ),
                      if (cat != settings.expensesCustomCategories.last)
                        const SettingsDivider(),
                    ],
                  ),
                ),
              const SettingsDivider(),
              SettingsTile(
                title: 'Ajouter une catégorie',
                trailing: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.primary,
                  size: 20,
                ),
                showChevron: false,
                onTap: () => _addCategory(settings),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
