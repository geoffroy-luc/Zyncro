import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/settings_widgets.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';

class NotesSettingsScreen extends ConsumerWidget {
  const NotesSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, TabSettings next) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref.read(tabSettingsRepositoryProvider).updateSettings(groupId, next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          'Paramètres Notes',
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
                  selected: settings.notesThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) => _update(ref, settings.copyWith(notesThemeColor: hex)),
                  onAddColor: (hex) => _update(
                    ref,
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
                  onDeleteColor: (hex) =>
                      _update(ref, settings.withColorRemoved(hex)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
