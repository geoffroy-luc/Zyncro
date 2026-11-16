import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/media/media_providers.dart';
import 'package:zyncro/core/media/media_source.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/chat/presentation/providers/chat_preferences_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/settings_widgets.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _loadingBg = false;

  Future<void> _update(TabSettings from, TabSettings to) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(groupId, from: from, to: to);
  }

  Future<void> _pickBackgroundImage() async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    final source = await showModalBottomSheet<MediaSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.chatPrendreUnePhoto),
              onTap: () => Navigator.pop(ctx, MediaSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.chatChoisirDepuisLaGalerie),
              onTap: () => Navigator.pop(ctx, MediaSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _loadingBg = true);
    try {
      final path = await ref
          .read(imagePickerServiceProvider)
          .pickImage(source: source, imageQuality: 80, maxWidth: 1080);
      if (path == null) return;

      final url = await ref
          .read(fileStorageProvider)
          .upload(
            path,
            StoragePaths.chatBackground(groupId),
            contentType: 'image/jpeg',
          );

      final settings =
          ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
      await _update(
        settings,
        settings.copyWith(
          chatBackgroundType: 'image',
          chatBackgroundValue: url,
        ),
      );
    } on Exception catch (e) {
      if (e.toString().contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.chatErreur2(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingBg = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final bgType = settings.chatBackgroundType;

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
          context.l10n.chatParametresChat,
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
            title: context.l10n.chatApparence,
            children: [
              SettingsTile(
                title: context.l10n.chatCouleurDuTheme,
                child: ColorPickerRow(
                  selected: settings.chatThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) =>
                      _update(settings, settings.copyWith(chatThemeColor: hex)),
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
            title: context.l10n.chatBackgroundDuChat,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                      value: 'none',
                      label: Text(context.l10n.chatAucun),
                      icon: const Icon(Icons.block, size: 16),
                    ),
                    ButtonSegment(
                      value: 'color',
                      label: Text(context.l10n.chatCouleur),
                      icon: const Icon(Icons.palette_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'image',
                      label: Text(context.l10n.chatImage),
                      icon: const Icon(Icons.image_outlined, size: 16),
                    ),
                  ],
                  selected: {bgType ?? 'none'},
                  onSelectionChanged: (Set<String> sel) async {
                    final type = sel.first;
                    if (type == 'none') {
                      await _update(
                        settings,
                        settings.copyWith(clearChatBackground: true),
                      );
                    } else if (type == 'color') {
                      await _update(
                        settings,
                        settings.copyWith(
                          chatBackgroundType: 'color',
                          chatBackgroundValue:
                              settings.chatBackgroundValue ?? '#F7F9FC',
                        ),
                      );
                    } else {
                      await _pickBackgroundImage();
                    }
                  },
                ),
              ),
              if (bgType == 'color') ...[
                const SettingsDivider(),
                SettingsTile(
                  title: context.l10n.chatCouleurDuFond,
                  child: ColorPickerRow(
                    selected: settings.chatBackgroundValue,
                    extraColors: settings.customColors,
                    hiddenBaseColors: settings.hiddenBaseColors,
                    onSelect: (hex) => _update(
                      settings,
                      settings.copyWith(
                        chatBackgroundType: 'color',
                        chatBackgroundValue: hex,
                      ),
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
              if (bgType == 'image' &&
                  settings.chatBackgroundValue != null) ...[
                const SettingsDivider(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      settings.chatBackgroundValue!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                SettingsTile(
                  title: context.l10n.chatChangerLImage,
                  onTap: _loadingBg ? null : _pickBackgroundImage,
                  trailing: _loadingBg
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
              ],
            ],
          ),
          SettingsSection(
            title: context.l10n.chatAffichage,
            children: [
              SettingsTile(
                title: context.l10n.chatActiviteDansLeChat,
                subtitle: context.l10n.chatActiviteDansLeChatDetail,
                trailing: Switch(
                  value: ref.watch(chatActivityVisibleProvider),
                  onChanged: (visible) => unawaited(
                    ref
                        .read(chatActivityVisibleProvider.notifier)
                        .set(visible: visible),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Médias',
            children: [
              SettingsTile(
                title: context.l10n.chatPhotosVideosPartagees,
                subtitle: context.l10n.chatVoirTousLesMediasDu,
                onTap: () => context.push(AppRoutes.mediaGallery),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
