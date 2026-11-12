part of 'home_settings_screen.dart';

/// Identité du groupe : emoji, photo, nom et description.
mixin _HomeSettingsGroupInfo on _HomeSettingsScreenStateBase {
  @override
  // ── Emoji / Photo du groupe ──────────────────────────────────────────────────
  Future<void> _showIconPicker(TabSettings settings, String groupEmoji) async {
    await showModalBottomSheet<void>(
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
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(context.l10n.dashboardChoisirUnEmoji),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickEmoji(groupEmoji));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.dashboardChoisirUnePhoto),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickGroupPhoto(MediaSource.gallery, settings));
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.dashboardPrendreUnePhoto),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_pickGroupPhoto(MediaSource.camera, settings));
              },
            ),
            if (settings.homePhotoUrl != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: context.colors.error,
                ),
                title: Text(
                  context.l10n.dashboardSupprimerLaPhoto,
                  style: TextStyle(color: context.colors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(_removeGroupPhoto(settings));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickEmoji(String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardEmojiDuGroupe),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 2,
          style: const TextStyle(fontSize: 32),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.dashboardEnregistrer),
          ),
        ],
      ),
    );
    if (result == null) return;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref
        .read(groupsRepositoryProvider)
        .updateGroupEmoji(groupId, result.isEmpty ? '🏠' : result);
  }

  Future<void> _pickGroupPhoto(MediaSource source, TabSettings settings) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    setState(() => _loadingPhoto = true);
    try {
      final path = await ref
          .read(imagePickerServiceProvider)
          .pickImage(
            source: source,
            imageQuality: 85,
            maxWidth: 512,
            maxHeight: 512,
          );
      if (path == null) return;
      final url = await ref
          .read(fileStorageProvider)
          .upload(
            path,
            StoragePaths.groupPhoto(groupId),
            contentType: 'image/jpeg',
          );
      // Sauvegarde sur le doc groupe (pour l'affichage partout) ET tabSettings
      await Future.wait([
        ref.read(groupsRepositoryProvider).updateGroupPhotoUrl(groupId, url),
        _updateTabSettings(settings, settings.copyWith(homePhotoUrl: url)),
      ]);
    } on Exception catch (e) {
      if (e.toString().contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashboardErreur(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _removeGroupPhoto(TabSettings settings) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    try {
      await ref
          .read(fileStorageProvider)
          .delete(StoragePaths.groupPhoto(groupId));
    } catch (_) {}
    await Future.wait([
      ref.read(groupsRepositoryProvider).updateGroupPhotoUrl(groupId, null),
      _updateTabSettings(settings, settings.copyWith(clearHomePhotoUrl: true)),
    ]);
  }

  @override
  // ── Group info ───────────────────────────────────────────────────────────────
  Future<void> _editGroupInfo(
    String groupId,
    String currentName,
    String? currentDescription,
  ) async {
    final nameController = TextEditingController(text: currentName);
    final descController = TextEditingController(
      text: currentDescription ?? '',
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardModifierLeGroupe),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: context.l10n.dashboardNom,
                ),
                maxLength: 30,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Champ requis';
                  if (v.trim().length > 30) return '30 caractères maximum';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: context.l10n.dashboardDescriptionOptionnel,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 150,
                maxLines: 2,
                validator: (v) {
                  if (v != null && v.trim().length > 150) {
                    return '150 caractères maximum';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: Text(context.l10n.dashboardEnregistrer),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref
          .read(groupsRepositoryProvider)
          .updateGroupInfo(
            groupId,
            name: nameController.text.trim(),
            description: descController.text.trim().isEmpty
                ? null
                : descController.text.trim(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashboardErreur(e))),
        );
      }
    }
  }
}
