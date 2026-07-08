import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/settings_widgets.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
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
            hintText: 'Ex : Anniversaire, Réunion...',
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
    final updated = [...settings.calendarCustomCategories, result];
    await _update(settings.copyWith(calendarCustomCategories: updated));
  }

  Future<void> _deleteCategory(TabSettings settings, String cat) async {
    final updated = settings.calendarCustomCategories
        .where((c) => c != cat)
        .toList();
    final filters = settings.calendarFilters;
    final updatedFilters = filters.category == cat
        ? filters.copyWith(clearCategory: true)
        : filters;
    await _update(
      settings.copyWith(
        calendarCustomCategories: updated,
        calendarFilters: updatedFilters,
      ),
    );
  }

  Future<void> _toggleParticipant(
    TabSettings settings,
    String uid,
    bool selected,
  ) async {
    final current = [...settings.calendarFilters.participantIds];
    if (selected) {
      if (!current.contains(uid)) current.add(uid);
    } else {
      current.remove(uid);
    }
    await _update(
      settings.copyWith(
        calendarFilters: settings.calendarFilters.copyWith(
          participantIds: current,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final members = ref.watch(groupMembersProvider).asData?.value ?? [];
    final filters = settings.calendarFilters;

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
          'Paramètres Calendrier',
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
                  selected: settings.calendarThemeColor,
                  extraColors: settings.customColors,
                  onSelect: (hex) =>
                      _update(settings.copyWith(calendarThemeColor: hex)),
                  onAddColor: (hex) => _update(
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Affichage',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'band',
                      label: Text('Bande'),
                      icon: Icon(Icons.view_agenda_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'dot',
                      label: Text('Point'),
                      icon: Icon(Icons.circle, size: 8),
                    ),
                  ],
                  selected: {settings.calendarDisplayMode},
                  onSelectionChanged: (Set<String> sel) =>
                      _update(settings.copyWith(calendarDisplayMode: sel.first)),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Catégories',
            children: [
              if (settings.calendarCustomCategories.isEmpty)
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
                ...settings.calendarCustomCategories.map(
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
                      if (cat != settings.calendarCustomCategories.last)
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
          SettingsSection(
            title: 'Filtres par défaut',
            children: [
              if (members.isNotEmpty) ...[
                SettingsTile(
                  title: 'Filtrer par participant',
                  subtitle: filters.participantIds.isEmpty
                      ? 'Tous les participants'
                      : '${filters.participantIds.length} sélectionné(s)',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: members.map((m) {
                      final selected =
                          filters.participantIds.contains(m.uid);
                      return FilterChip(
                        label: Text(
                          m.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        onSelected: (val) =>
                            _toggleParticipant(settings, m.uid, val),
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppColors.background,
                        side: const BorderSide(color: AppColors.border),
                        showCheckmark: false,
                        avatar: selected
                            ? null
                            : Text(
                                m.displayName.isNotEmpty
                                    ? m.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(fontSize: 12),
                              ),
                      );
                    }).toList(),
                  ),
                ),
                const SettingsDivider(),
              ],
              SettingsTile(
                title: 'Récurrents uniquement',
                trailing: Switch(
                  value: filters.recurrenceOnly,
                  onChanged: (val) => _update(
                    settings.copyWith(
                      calendarFilters: filters.copyWith(recurrenceOnly: val),
                    ),
                  ),
                ),
                showChevron: false,
              ),
              if (settings.calendarCustomCategories.isNotEmpty) ...[
                const SettingsDivider(),
                SettingsTile(
                  title: 'Catégorie',
                  subtitle: filters.category ?? 'Toutes les catégories',
                  trailing: filters.category != null
                      ? IconButton(
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _update(
                            settings.copyWith(
                              calendarFilters: filters.copyWith(
                                clearCategory: true,
                              ),
                            ),
                          ),
                        )
                      : null,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: settings.calendarCustomCategories.map((cat) {
                      final selected = filters.category == cat;
                      return ChoiceChip(
                        label: Text(
                          cat,
                          style: TextStyle(
                            fontSize: 13,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        onSelected: (val) => _update(
                          settings.copyWith(
                            calendarFilters: val
                                ? filters.copyWith(category: cat)
                                : filters.copyWith(clearCategory: true),
                          ),
                        ),
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        side: const BorderSide(color: AppColors.border),
                        showCheckmark: false,
                      );
                    }).toList(),
                  ),
                ),
              ],
              if (!filters.isEmpty) ...[
                const SettingsDivider(),
                SettingsTile(
                  title: 'Réinitialiser les filtres',
                  trailing: const Icon(
                    Icons.refresh,
                    color: AppColors.error,
                    size: 20,
                  ),
                  showChevron: false,
                  onTap: () => _update(
                    settings.copyWith(
                      calendarFilters: const CalendarFilters(),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
