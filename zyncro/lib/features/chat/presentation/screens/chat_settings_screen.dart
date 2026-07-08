import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/settings_widgets.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';

class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key});

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  bool _loadingBg = false;

  Future<void> _update(TabSettings next) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref.read(tabSettingsRepositoryProvider).updateSettings(groupId, next);
  }

  Future<void> _pickBackgroundImage() async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;

    final source = await showModalBottomSheet<ImageSource>(
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    setState(() => _loadingBg = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (file == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_backgrounds/$groupId.jpg');
      await ref.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await ref.getDownloadURL();

      final settings =
          this.ref.read(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
      await _update(
        settings.copyWith(chatBackgroundType: 'image', chatBackgroundValue: url),
      );
    } on Exception catch (e) {
      if (e.toString().contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
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
          'Paramètres Chat',
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
                  selected: settings.chatThemeColor,
                  extraColors: settings.customColors,
                  onSelect: (hex) =>
                      _update(settings.copyWith(chatThemeColor: hex)),
                  onAddColor: (hex) => _update(
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Background du chat',
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'none',
                      label: Text('Aucun'),
                      icon: Icon(Icons.block, size: 16),
                    ),
                    ButtonSegment(
                      value: 'color',
                      label: Text('Couleur'),
                      icon: Icon(Icons.palette_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: 'image',
                      label: Text('Image'),
                      icon: Icon(Icons.image_outlined, size: 16),
                    ),
                  ],
                  selected: {bgType ?? 'none'},
                  onSelectionChanged: (Set<String> sel) async {
                    final type = sel.first;
                    if (type == 'none') {
                      await _update(settings.copyWith(clearChatBackground: true));
                    } else if (type == 'color') {
                      await _update(
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
                  title: 'Couleur du fond',
                  child: ColorPickerRow(
                    selected: settings.chatBackgroundValue,
                    extraColors: settings.customColors,
                    onSelect: (hex) => _update(
                      settings.copyWith(
                        chatBackgroundType: 'color',
                        chatBackgroundValue: hex,
                      ),
                    ),
                    onAddColor: (hex) => _update(
                      settings.copyWith(customColors: [...settings.customColors, hex]),
                    ),
                  ),
                ),
              ],
              if (bgType == 'image' && settings.chatBackgroundValue != null) ...[
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
                    ),
                  ),
                ),
                SettingsTile(
                  title: 'Changer l\'image',
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
            title: 'Médias',
            children: [
              SettingsTile(
                title: 'Photos & vidéos partagées',
                subtitle: 'Voir tous les médias du groupe',
                onTap: () => context.push('/media-gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
