import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group_member.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../providers/groups_provider.dart';

// ── Members stream provider ──────────────────────────────────────────────────

final membersProvider = StreamProvider<List<GroupMember>>((ref) {
  final groupId = ref.watch(selectedGroupIdProvider).asData?.value;
  if (groupId == null) return Stream.value([]);
  return ref.watch(groupsRepositoryProvider).watchMembers(groupId);
});

// ── Screen ───────────────────────────────────────────────────────────────────

class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key});

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  bool _generating = false;

  Future<void> _editMyPseudo(BuildContext context, String groupId, String currentPseudo) async {
    final controller = TextEditingController(text: currentPseudo);
    final formKey = GlobalKey<FormState>();

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
        groupId,
        user.uid,
        newPseudo,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  Future<void> _editGroupInfo(BuildContext context, String groupId, String currentName, String? currentDescription) async {
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

  Future<void> _generateCode(String groupId) async {
    setState(() => _generating = true);
    try {
      await ref.read(groupsRepositoryProvider).generateInviteCode(groupId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = ref.watch(selectedGroupProvider);
    final membersAsync = ref.watch(membersProvider);
    final currentUser = ref.watch(authStateProvider).asData?.value;

    if (group == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isOwner = group.createdBy == currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Paramètres du groupe')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Group info ───────────────────────────────────────────
          _Section(
            title: 'Espace',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          group.emoji ?? group.name[0].toUpperCase(),
                          style: const TextStyle(fontSize: 26),
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
                          context,
                          group.id,
                          group.name,
                          group.description,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        color: AppColors.textSecondary,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Invite code ──────────────────────────────────────────
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
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (group.inviteCode == null) ...[
                      ElevatedButton.icon(
                        onPressed: _generating
                            ? null
                            : () => _generateCode(group.id),
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
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
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
                              Clipboard.setData(
                                ClipboardData(text: group.inviteCode!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code copié !'),
                                ),
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

          // ── Members ──────────────────────────────────────────────
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
                        color: _avatarColor(member.uid),
                      ),
                      title: Text(
                        member.displayName +
                            (isCurrentUser ? ' (moi)' : ''),
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
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                              tooltip: 'Changer mon pseudo',
                              onPressed: () => _editMyPseudo(context, group.id, member.displayName),
                            )
                          : isOwner && !member.isOwner
                          ? PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: AppColors.textSecondary,
                                size: 20,
                              ),
                              onSelected: (action) {
                                if (action == 'transfer') {
                                  _confirmTransferOwnership(context, ref, member);
                                } else if (action == 'remove') {
                                  _confirmRemove(context, ref, member);
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
                                      Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                                      SizedBox(width: 10),
                                      Text('Retirer du groupe', style: TextStyle(color: AppColors.error)),
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

          // ── Leave group ──────────────────────────────────────────
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
                : () => _confirmLeave(context, ref, currentUser?.uid),
            style: TextButton.styleFrom(
              foregroundColor: isOwner ? AppColors.textSecondary : AppColors.error,
            ),
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Quitter ce groupe'),
          ),

          if (isOwner) ...[
            const Divider(height: 32),
            TextButton.icon(
              onPressed: () => _confirmDeleteGroup(context, ref, group.id, group.inviteCode),
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

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    WidgetRef ref,
    String groupId,
    String? inviteCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le groupe'),
        content: const Text(
          'Cette action est irréversible. Tout le contenu du groupe (messages, notes, dépenses, événements) sera perdu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _confirmTransferOwnership(
    BuildContext context,
    WidgetRef ref,
    GroupMember newOwner,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Transférer la propriété'),
        content: Text(
          'Nommer ${newOwner.displayName} propriétaire du groupe ? Tu deviendras simple membre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Transférer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final groupId = ref.read(selectedGroupIdProvider).asData?.value;
    final currentUser = ref.read(authStateProvider).asData?.value;
    if (groupId == null || currentUser == null) return;

    try {
      await ref.read(groupsRepositoryProvider).transferOwnership(
        groupId,
        currentUser.uid,
        newOwner.uid,
      );
      final ownerName = ref.read(currentMemberProvider).asData?.value?.displayName ??
          currentUser.displayName ??
          currentUser.email ??
          'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: currentUser.uid,
        content: '👑 $ownerName a transféré la propriété du groupe à ${newOwner.displayName}',
        notifScreen: 'chat',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    GroupMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Retirer le membre'),
        content: Text(
          'Retirer ${member.displayName} du groupe ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
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
          currentUser.displayName ??
          currentUser.email ??
          'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: groupId,
        userId: currentUser.uid,
        content: '👋 $ownerName a retiré ${member.displayName} du groupe',
        notifScreen: 'chat',
      );
    }
  }

  Future<void> _confirmLeave(
    BuildContext context,
    WidgetRef ref,
    String? userId,
  ) async {
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Quitter le groupe'),
        content: const Text(
          'Es-tu sûr de vouloir quitter ce groupe ? Tu ne pourras plus accéder à son contenu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
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
        user?.displayName ??
        user?.email ??
        'Quelqu\'un';

    try {
      // Message inclus dans le même batch que le leave → atomique
      await ref.read(groupsRepositoryProvider).leaveGroup(
        groupId,
        userId,
        systemMessage: '👋 $userName a quitté le groupe',
      );
      await ref.read(selectedGroupIdProvider.notifier).select(null);
      if (context.mounted) context.go('/groups');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de quitter le groupe. Vérifie les règles Firestore.'),
          ),
        );
      }
    }
  }

  Color _avatarColor(String uid) {
    const colors = [
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFFEF4444),
      Color(0xFFF97316),
      Color(0xFF10B981),
      Color(0xFF14B8A6),
      Color(0xFF3B82F6),
    ];
    return colors[uid.hashCode.abs() % colors.length];
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
