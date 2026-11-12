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
import 'package:zyncro/features/auth/domain/entities/app_user.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/dashboard/presentation/widgets/home_settings_section.dart';
import 'package:zyncro/features/groups/domain/entities/group.dart';
import 'package:zyncro/features/groups/domain/entities/group_member.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/settings/domain/entities/tab_settings.dart';
import 'package:zyncro/features/settings/presentation/providers/tab_settings_provider.dart';
import 'package:zyncro/shared/widgets/color_picker_row.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

part 'home_settings_group_info.dart';
part 'home_settings_membership.dart';
part 'home_settings_screen_sections.dart';

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
          context.l10n.dashboardParametresAccueil,
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
          _buildSpaceSection(
            group,
            settings,
            primary,
            isOwner,
            photoUrl,
            emoji,
          ),

          // ── Code d'invitation ────────────────────────────────────────
          _buildInviteSection(group, primary),

          // ── Couleur du thème ─────────────────────────────────────────
          _buildThemeColorSection(settings),

          // ── Membres ──────────────────────────────────────────────────
          _buildMembersSection(
            group,
            membersAsync,
            currentUser,
            primary,
            isOwner,
            photoUrl,
          ),

          const SizedBox(height: 8),

          // ── Quitter ──────────────────────────────────────────────────
          TextButton.icon(
            onPressed: isOwner
                ? () => showDialog<void>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(context.l10n.dashboardImpossibleDeQuitter),
                      content: Text(
                        context.l10n.dashboardTuEsProprietaireDuGroupe,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(context.l10n.dashboardOk),
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
            label: Text(context.l10n.dashboardQuitterCeGroupe),
          ),

          if (isOwner) ...[
            const Divider(height: 32),
            TextButton.icon(
              onPressed: () => _confirmDeleteGroup(group.id, group.inviteCode),
              style: TextButton.styleFrom(
                foregroundColor: context.colors.error,
              ),
              icon: const Icon(Icons.delete_forever_outlined),
              label: Text(context.l10n.dashboardSupprimerLeGroupe),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Implémentées par les mixins ──
  Widget _buildSpaceSection(
    Group group,
    TabSettings settings,
    Color primary,
    bool isOwner,
    String? photoUrl,
    String emoji,
  );
  Widget _buildInviteSection(Group group, Color primary);
  Widget _buildThemeColorSection(TabSettings settings);
  Widget _buildMembersSection(
    Group group,
    AsyncValue<List<GroupMember>> membersAsync,
    AppUser? currentUser,
    Color primary,
    bool isOwner,
    String? photoUrl,
  );
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
    with
        _HomeSettingsGroupInfo,
        _HomeSettingsMembership,
        _HomeSettingsScreenSections {}
