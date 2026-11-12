import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/settings_widgets.dart';

class NotesSettingsScreen extends ConsumerWidget {
  const NotesSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, TabSettings from, TabSettings to) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(groupId, from: from, to: to);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          context.l10n.notesParametresNotes,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: context.colors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SettingsSection(
            title: context.l10n.notesApparence,
            children: [
              SettingsTile(
                title: context.l10n.notesCouleurDuTheme,
                child: ColorPickerRow(
                  selected: settings.notesThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) => _update(
                    ref,
                    settings,
                    settings.copyWith(notesThemeColor: hex),
                  ),
                  onAddColor: (hex) => _update(
                    ref,
                    settings,
                    settings.copyWith(
                      customColors: [...settings.customColors, hex],
                    ),
                  ),
                  onDeleteColor: (hex) =>
                      _update(ref, settings, settings.withColorRemoved(hex)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
