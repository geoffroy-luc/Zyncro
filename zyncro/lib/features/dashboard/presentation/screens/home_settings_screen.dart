import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group_member.dart';
import '../../../../shared/models/tab_settings.dart';
import '../../../../shared/widgets/color_picker_row.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../../groups/presentation/providers/tab_settings_provider.dart';

class HomeSettingsScreen extends ConsumerStatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  ConsumerState<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

class _HomeSettingsScreenState extends ConsumerState<HomeSettingsScreen> {
  bool _generating = false;
  bool _loadingPhoto = false;

  // ── Tab settings ────────────────────────────────────────────────────────────

  Future<void> _updateTabSettings(TabSettings next) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref.read(tabSettingsRepositoryProvider).updateSettings(groupId, next);
  }

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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: const Text('Choisir un emoji'),
              onTap: () {
                Navigator.pop(ctx);
                _pickEmoji(groupEmoji);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGroupPhoto(ImageSource.gallery, settings);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickGroupPhoto(ImageSource.camera, settings);
              },
            ),
            if (settings.homePhotoUrl != null)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: const Text(
                  'Supprimer la photo',
                  style: TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeGroupPhoto(settings);
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
        title: const Text('Emoji du groupe'),
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
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .update({'emoji': result.isEmpty ? '🏠' : result});
  }

  Future<void> _pickGroupPhoto(ImageSource source, TabSettings settings) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    setState(() => _loadingPhoto = true);
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 512,
        maxHeight: 512,
      );
      if (file == null) return;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('group_photos/$groupId.jpg');
      await storageRef.putFile(
        File(file.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await storageRef.getDownloadURL();
      // Sauvegarde sur le doc groupe (pour l'affichage partout) ET tabSettings
      await Future.wait([
        FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .update({'photoUrl': url}),
        _updateTabSettings(settings.copyWith(homePhotoUrl: url)),
      ]);
    } on Exception catch (e) {
      if (e.toString().contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
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
      await FirebaseStorage.instance
          .ref()
          .child('group_photos/$groupId.jpg')
          .delete();
    } catch (_) {}
    await Future.wait([
      FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .update({'photoUrl': null}),
      _updateTabSettings(settings.copyWith(clearHomePhotoUrl: true)),
    ]);
  }

  // ── Group info ───────────────────────────────────────────────────────────────

  Future<void> _editGroupInfo(String groupId, String currentName, String? currentDescription) async {
    final nameController = TextEditingController(text: currentName);
    final descController = TextEditingController(text: currentDescription ?? '');
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Modifier le groupe'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nom'),
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
                decoration: const InputDecoration(labelText: 'Description (optionnel)'),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 150,
                maxLines: 2,
                validator: (v) {
                  if (v != null && v.trim().length > 150) return '150 caractères maximum';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await ref.read(groupsRepositoryProvider).updateGroupInfo(
        groupId,
        name: nameController.text.trim(),
        description: descController.text.trim().isEmpty ? null : descController.text.trim(),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _editMyPseudo(String groupId, String currentPseudo) async {
    final controller = TextEditingController(text: currentPseudo);
    final formKey = GlobalKey<FormState>();
    final currentUser = ref.read(authStateProvider).asData?.value;
    final members = ref.read(groupMembersProvider).asData?.value ?? [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mon pseudo dans ce groupe'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Pseudo'),
            maxLength: 30,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (v.trim().length > 30) return '30 caractères maximum';
              final trimmed = v.trim().toLowerCase();
              final isDuplicate = members.any((m) =>
                m.uid != currentUser?.uid &&
                m.displayName.toLowerCase() == trimmed,
              );
              if (isDuplicate) return 'Ce pseudo est déjà utilisé dans ce groupe';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final newPseudo = controller.text.trim();
    if (newPseudo == currentPseudo) return;

    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    try {
      await ref.read(groupsRepositoryProvider).updateMemberDisplayName(
        groupId, user.uid, newPseudo,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _generateCode(String groupId) async {
    setState(() => _generating = true);
    try {
      await ref.read(groupsRepositoryProvider).generateInviteCode(groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  // ── Leave / Delete ───────────────────────────────────────────────────────────

  Future<void> _confirmLeave(String? userId) async {
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text('Es-tu sûr de vouloir quitter ce groupe ? Tu ne pourras plus accéder à son contenu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final user = ref.read(authStateProvider).asData?.value;
    final userName = ref.read(currentMemberProvider).asData?.value?.displayName ??
        user?.displayName ?? user?.email ?? 'Quelqu\'un';
    try {
      await ref.read(groupsRepositoryProvider).leaveGroup(
        groupId, userId, systemMessage: '👋 $userName a quitté le groupe',
      );
      await ref.read(selectedGroupIdProvider.notifier).select(null);
      if (context.mounted) context.go('/groups');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de quitter le groupe.')),
        );
      }
    }
  }

  Future<void> _confirmDeleteGroup(String groupId, String? inviteCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text('Cette action est irréversible. Tout le contenu du groupe sera perdu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(groupId, inviteCode);
      await ref.read(selectedGroupIdProvider.notifier).select(null);
      if (context.mounted) context.go('/groups');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _confirmTransferOwnership(GroupMember newOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transférer la propriété'),
        content: Text('Nommer ${newOwner.displayName} propriétaire du groupe ? Tu deviendras simple membre.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Transférer')),
        ],
      ),
    );
    if (confirmed != true) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final currentUser = ref.read(authStateProvider).asData?.value;
    if (groupId == null || currentUser == null) return;
    try {
      await ref.read(groupsRepositoryProvider).transferOwnership(groupId, currentUser.uid, newOwner.uid);
      final ownerName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          currentUser.displayName ?? currentUser.email ?? 'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: currentUser.uid,
        content: '👑 $ownerName a transféré la propriété du groupe à ${newOwner.displayName}',
        notifScreen: 'chat',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _confirmRemove(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text('Retirer ${member.displayName} du groupe ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final currentUser = ref.read(authStateProvider).asData?.value;
    await ref.read(groupsRepositoryProvider).removeMember(groupId, member.uid);
    if (currentUser != null) {
      final ownerName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          currentUser.displayName ?? currentUser.email ?? 'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: currentUser.uid,
        content: '👋 $ownerName a retiré ${member.displayName} du groupe',
        notifScreen: 'chat',
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(selectedGroupProvider);
    final membersAsync = ref.watch(groupMembersProvider);
    final currentUser = ref.watch(authStateProvider).asData?.value;
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = group.createdBy == currentUser?.uid;
    final photoUrl = settings.homePhotoUrl;
    final emoji = group.emoji ?? group.name[0].toUpperCase();

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
          'Paramètres Accueil',
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

          // ── Espace ──────────────────────────────────────────────────
          _Section(
            title: 'Espace',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Emoji / photo — tappable uniquement pour le propriétaire
                    GestureDetector(
                      onTap: isOwner
                          ? () => _showIconPicker(settings, group.emoji ?? '')
                          : null,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _loadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : photoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.network(
                                      photoUrl,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      emoji,
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (group.description != null)
                            Text(
                              group.description!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          Text(
                            '${group.memberIds.length} membre${group.memberIds.length > 1 ? 's' : ''}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        onPressed: () => _editGroupInfo(
                          group.id, group.name, group.description,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Code d'invitation ────────────────────────────────────────
          _Section(
            title: "Code d'invitation",
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Partage ce code pour inviter quelqu\'un dans ce groupe.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    if (group.inviteCode == null)
                      ElevatedButton.icon(
                        onPressed: _generating ? null : () => _generateCode(group.id),
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.vpn_key_outlined, size: 18),
                        label: const Text('Générer un code'),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                              ),
                              child: Text(
                                group.inviteCode!,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: group.inviteCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copié !')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Couleur du thème ─────────────────────────────────────────
          _Section(
            title: 'Couleur du thème',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ColorPickerRow(
                  selected: settings.homeThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) =>
                      _updateTabSettings(settings.copyWith(homeThemeColor: hex)),
                  onAddColor: (hex) => _updateTabSettings(
                    settings.copyWith(customColors: [...settings.customColors, hex]),
                  ),
                  onDeleteColor: (hex) =>
                      _updateTabSettings(settings.withColorRemoved(hex)),
                ),
              ),
            ),
          ),

          // ── Membres ──────────────────────────────────────────────────
          _Section(
            title: 'Membres',
            child: membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Erreur : $e'),
              data: (members) => Card(
                child: Column(
                  children: members.map((member) {
                    final isCurrentUser = member.uid == currentUser?.uid;
                    return ListTile(
                      leading: UserAvatar(
                        photoUrl: member.photoUrl,
                        showPhoto: member.showProfilePhoto,
                        displayName: member.displayName,
                        radius: 20,
                        color: avatarColorForUid(member.uid),
                      ),
                      title: Text(
                        member.displayName + (isCurrentUser ? ' (moi)' : ''),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        member.isOwner ? 'Propriétaire' : 'Membre',
                        style: TextStyle(
                          fontSize: 12,
                          color: member.isOwner
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      trailing: isCurrentUser
                          ? IconButton(
                              icon: const Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.textSecondary),
                              tooltip: 'Changer mon pseudo',
                              onPressed: () =>
                                  _editMyPseudo(group.id, member.displayName),
                            )
                          : isOwner && !member.isOwner
                          ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert,
                                  color: AppColors.textSecondary, size: 20),
                              onSelected: (action) {
                                if (action == 'transfer') {
                                  _confirmTransferOwnership(member);
                                } else if (action == 'remove') {
                                  _confirmRemove(member);
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(Icons.workspace_premium_outlined, size: 18),
                                      SizedBox(width: 10),
                                      Text('Nommer propriétaire'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(Icons.person_remove_outlined,
                                          size: 18, color: AppColors.error),
                                      SizedBox(width: 10),
                                      Text('Retirer du groupe',
                                          style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : null,
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Quitter ──────────────────────────────────────────────────
          TextButton.icon(
            onPressed: isOwner
                ? () => showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Impossible de quitter'),
                        content: const Text(
                          'Tu es propriétaire du groupe. Transfère la propriété à un autre membre avant de quitter.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    )
                : () => _confirmLeave(currentUser?.uid),
            style: TextButton.styleFrom(
              foregroundColor: isOwner ? AppColors.textSecondary : AppColors.error,
            ),
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Quitter ce groupe'),
          ),

          if (isOwner) ...[
            const Divider(height: 32),
            TextButton.icon(
              onPressed: () => _confirmDeleteGroup(group.id, group.inviteCode),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Supprimer le groupe'),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Section widget ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
