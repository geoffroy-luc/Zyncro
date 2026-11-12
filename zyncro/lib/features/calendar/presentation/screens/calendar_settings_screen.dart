import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/settings_widgets.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  Future<void> _update(TabSettings from, TabSettings to) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(groupId, from: from, to: to);
  }

  @override
  Widget build(BuildContext context) {
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
          'Paramètres Calendrier',
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
            title: 'Apparence',
            children: [
              SettingsTile(
                title: 'Couleur du thème',
                child: ColorPickerRow(
                  selected: settings.calendarThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) => _update(
                    settings,
                    settings.copyWith(calendarThemeColor: hex),
                  ),
                  onAddColor: (hex) => _update(
                    settings,
                    settings.copyWith(
                      customColors: [...settings.customColors, hex],
                    ),
                  ),
                  onDeleteColor: (hex) =>
                      _update(settings, settings.withColorRemoved(hex)),
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
                  onSelectionChanged: (Set<String> sel) => _update(
                    settings,
                    settings.copyWith(calendarDisplayMode: sel.first),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
