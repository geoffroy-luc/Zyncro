part of 'home_settings_screen.dart';

/// Pseudo, code d'invitation, quitter / supprimer, propriété, retrait d'un membre.
mixin _HomeSettingsMembership on _HomeSettingsScreenStateBase {
  @override
  Future<void> _editMyPseudo(String groupId, String currentPseudo) async {
    final controller = TextEditingController(text: currentPseudo);
    final formKey = GlobalKey<FormState>();
    final currentUser = ref.read(authStateProvider).asData?.value;
    final members = ref.read(groupMembersProvider).asData?.value ?? [];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardMonPseudoDansCeGroupe),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: context.l10n.dashboardPseudo,
            ),
            maxLength: 30,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Champ requis';
              if (v.trim().length > 30) return '30 caractères maximum';
              final trimmed = v.trim().toLowerCase();
              final isDuplicate = members.any(
                (m) =>
                    m.uid != currentUser?.uid &&
                    m.displayName.toLowerCase() == trimmed,
              );
              if (isDuplicate) {
                return 'Ce pseudo est déjà utilisé dans ce groupe';
              }
              return null;
            },
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
    final newPseudo = controller.text.trim();
    if (newPseudo == currentPseudo) return;

    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    try {
      await ref
          .read(groupsRepositoryProvider)
          .updateMemberDisplayName(groupId, user.uid, newPseudo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Future<void> _confirmRegenerate(String groupId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(context.l10n.dashboardRegenererLeLien),
        content: Text(context.l10n.dashboardRegenerateCodeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text(context.l10n.dashboardRegenerer),
          ),
        ],
      ),
    );
    if (confirmed == true) await _generateCode(groupId);
  }

  @override
  Future<void> _generateCode(String groupId) async {
    setState(() => _generating = true);
    try {
      await ref.read(groupsRepositoryProvider).generateInviteCode(groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashboardErreur(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  // ── Leave / Delete ───────────────────────────────────────────────────────────
  Future<void> _confirmLeave(String? userId) async {
    if (userId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardQuitterLeGroupe),
        content: Text(context.l10n.dashboardEsTuSurDeVouloir),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text(context.l10n.dashboardQuitter),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    if (groupId == null) return;
    final user = ref.read(authStateProvider).asData?.value;
    final userName =
        ref.read(currentMemberProvider).asData?.value?.displayName ??
        user?.displayName ??
        user?.email ??
        'Quelqu\'un';
    try {
      await ref
          .read(groupsRepositoryProvider)
          .leaveGroup(
            groupId,
            userId,
            systemMessage: '👋 $userName a quitté le groupe',
          );
      await ref.read(selectedGroupIdProvider.notifier).select(null);
      if (mounted) context.go(AppRoutes.groups);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.dashboardImpossibleDeQuitterLeGroupe),
          ),
        );
      }
    }
  }

  @override
  Future<void> _confirmDeleteGroup(String groupId, String? inviteCode) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardSupprimerLeGroupe),
        content: Text(context.l10n.dashboardCetteActionEstIrreversibleTout),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            child: Text(context.l10n.dashboardSupprimer),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(groupsRepositoryProvider).deleteGroup(groupId, inviteCode);
      await ref.read(selectedGroupIdProvider.notifier).select(null);
      if (mounted) context.go(AppRoutes.groups);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashboardErreur(e))),
        );
      }
    }
  }

  @override
  Future<void> _confirmTransferOwnership(GroupMember newOwner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardTransfererLaPropriete),
        content: Text(
          context.l10n.dashboardNommerProprietaireDuGroupeTu(
            newOwner.displayName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.dashboardTransferer),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final currentUser = ref.read(authStateProvider).asData?.value;
    if (groupId == null || currentUser == null) return;
    try {
      await ref
          .read(groupsRepositoryProvider)
          .transferOwnership(groupId, currentUser.uid, newOwner.uid);
      final ownerName =
          ref.read(currentMemberProvider).asData?.value?.displayName ??
          currentUser.displayName ??
          currentUser.email ??
          'Quelqu\'un';
      unawaited(
        ref
            .read(messagesRepositoryProvider)
            .sendSystemMessage(
              groupId: groupId,
              userId: currentUser.uid,
              content:
                  '👑 $ownerName a transféré la propriété du groupe à ${newOwner.displayName}',
              notifScreen: 'chat',
            ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashboardErreur(e))),
        );
      }
    }
  }

  @override
  Future<void> _confirmRemove(GroupMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboardRetirerLeMembre),
        content: Text(
          context.l10n.dashboardRetirerDuGroupe(member.displayName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.dashboardAnnuler),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.colors.error),
            child: Text(context.l10n.dashboardRetirer),
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
      final ownerName =
          ref.read(currentMemberProvider).asData?.value?.displayName ??
          currentUser.displayName ??
          currentUser.email ??
          'Quelqu\'un';
      unawaited(
        ref
            .read(messagesRepositoryProvider)
            .sendSystemMessage(
              groupId: groupId,
              userId: currentUser.uid,
              content: '👋 $ownerName a retiré ${member.displayName} du groupe',
              notifScreen: 'chat',
            ),
      );
    }
  }
}
