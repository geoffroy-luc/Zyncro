import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/firebase/firestore_paths.dart';
import 'package:zyncro/core/media/media_providers.dart';
import 'package:zyncro/core/media/media_source.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/core/utils/color_hex.dart';
import 'package:zyncro/core/utils/invite_share.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/home_settings_section.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

part 'home_settings_group_info.dart';
part 'home_settings_membership.dart';

class HomeSettingsScreen extends ConsumerStatefulWidget {
  const HomeSettingsScreen({super.key});

  @override
  ConsumerState<HomeSettingsScreen> createState() => _HomeSettingsScreenState();
}

/// Champs et contrat commun des mixins de l'écran (parts home_settings_group_info.dart, home_settings_membership.dart).
abstract class _HomeSettingsScreenStateBase
    extends ConsumerState<HomeSettingsScreen> {
  bool _generating = false;
  bool _loadingPhoto = false;

  // ── Tab settings ────────────────────────────────────────────────────────────

  Future<void> _updateTabSettings(TabSettings from, TabSettings to) async {
    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    await ref
        .read(tabSettingsRepositoryProvider)
        .updateSettings(groupId, from: from, to: to);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(selectedGroupProvider);
    final membersAsync = ref.watch(groupMembersProvider);
    final currentUser = ref.watch(authStateProvider).asData?.value;
    final settings =
        ref.watch(tabSettingsProvider).asData?.value ?? TabSettings.defaults;
    final primary = hexToColor(settings.homeThemeColor ?? '#9B59B6');

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = group.createdBy == currentUser?.uid;
    final photoUrl = settings.homePhotoUrl;
    final emoji = group.emoji ?? group.name[0].toUpperCase();

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
          'Paramètres Accueil',
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
          // ── Espace ──────────────────────────────────────────────────
          HomeSettingsSection(
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
                          color: primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: _loadingPhoto
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
                              style: TextStyle(
                                fontSize: 13,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          Text(
                            '${group.memberIds.length} membre${group.memberIds.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.colors.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isOwner)
                      IconButton(
                        onPressed: () => _editGroupInfo(
                          group.id,
                          group.name,
                          group.description,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: context.colors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Code d'invitation ────────────────────────────────────────
          HomeSettingsSection(
            title: "Code d'invitation",
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Partage le lien ou le code pour inviter quelqu\'un dans ce groupe.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (group.inviteCode == null)
                      ElevatedButton.icon(
                        onPressed: _generating
                            ? null
                            : () => _generateCode(group.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                        ),
                        icon: _generating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.vpn_key_outlined, size: 18),
                        label: const Text('Générer un code'),
                      )
                    else ...[
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                group.inviteCode!,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                  color: primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: () {
                              unawaited(
                                Clipboard.setData(
                                  ClipboardData(text: group.inviteCode!),
                                ),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copié !')),
                              );
                            },
                            icon: const Icon(Icons.copy),
                            style: IconButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => shareInviteLink(
                            code: group.inviteCode!,
                            groupName: group.name,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.ios_share, size: 18),
                          label: const Text('Partager le lien d\'invitation'),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: _generating
                              ? null
                              : () => _confirmRegenerate(group.id),
                          icon: _generating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 18),
                          label: const Text('Régénérer le lien'),
                          style: TextButton.styleFrom(foregroundColor: primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ── Couleur du thème ─────────────────────────────────────────
          HomeSettingsSection(
            title: 'Couleur du thème',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ColorPickerRow(
                  selected: settings.homeThemeColor,
                  extraColors: settings.customColors,
                  hiddenBaseColors: settings.hiddenBaseColors,
                  onSelect: (hex) => _updateTabSettings(
                    settings,
                    settings.copyWith(homeThemeColor: hex),
                  ),
                  onAddColor: (hex) => _updateTabSettings(
                    settings,
                    settings.copyWith(
                      customColors: [...settings.customColors, hex],
                    ),
                  ),
                  onDeleteColor: (hex) => _updateTabSettings(
                    settings,
                    settings.withColorRemoved(hex),
                  ),
                ),
              ),
            ),
          ),

          // ── Membres ──────────────────────────────────────────────────
          HomeSettingsSection(
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
                              ? primary
                              : context.colors.textSecondary,
                        ),
                      ),
                      trailing: isCurrentUser
                          ? IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: context.colors.textSecondary,
                              ),
                              tooltip: 'Changer mon pseudo',
                              onPressed: () =>
                                  _editMyPseudo(group.id, member.displayName),
                            )
                          : isOwner && !member.isOwner
                          ? PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: context.colors.textSecondary,
                                size: 20,
                              ),
                              onSelected: (action) {
                                if (action == 'transfer') {
                                  unawaited(_confirmTransferOwnership(member));
                                } else if (action == 'remove') {
                                  unawaited(_confirmRemove(member));
                                }
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'transfer',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.workspace_premium_outlined,
                                        size: 18,
                                      ),
                                      SizedBox(width: 10),
                                      Text('Nommer propriétaire'),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.person_remove_outlined,
                                        size: 18,
                                        color: context.colors.error,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Retirer du groupe',
                                        style: TextStyle(
                                          color: context.colors.error,
                                        ),
                                      ),
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
                ? () => showDialog<void>(
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
              foregroundColor: isOwner
                  ? context.colors.textSecondary
                  : context.colors.error,
            ),
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Quitter ce groupe'),
          ),

          if (isOwner) ...[
            const Divider(height: 32),
            TextButton.icon(
              onPressed: () => _confirmDeleteGroup(group.id, group.inviteCode),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Supprimer le groupe'),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Implémentées par les mixins ──
  Future<void> _showIconPicker(TabSettings settings, String groupEmoji);
  Future<void> _editGroupInfo(
    String groupId,
    String currentName,
    String? currentDescription,
  );
  Future<void> _editMyPseudo(String groupId, String currentPseudo);
  Future<void> _confirmRegenerate(String groupId);
  Future<void> _generateCode(String groupId);
  Future<void> _confirmLeave(String? userId);
  Future<void> _confirmDeleteGroup(String groupId, String? inviteCode);
  Future<void> _confirmTransferOwnership(GroupMember newOwner);
  Future<void> _confirmRemove(GroupMember member);
}

class _HomeSettingsScreenState extends _HomeSettingsScreenStateBase
    with _HomeSettingsGroupInfo, _HomeSettingsMembership {}
