import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group_member.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
                      leading: CircleAvatar(
                        backgroundColor: _avatarColor(member.uid),
                        child: Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      trailing: isOwner && !isCurrentUser && !member.isOwner
                          ? IconButton(
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: AppColors.error,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _confirmRemove(context, ref, member),
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
            onPressed: () => _confirmLeave(context, ref, currentUser?.uid),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            icon: const Icon(Icons.exit_to_app_outlined),
            label: const Text('Quitter ce groupe'),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
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
    await ref.read(groupsRepositoryProvider).removeMember(groupId, member.uid);
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
    await ref.read(groupsRepositoryProvider).leaveGroup(groupId, userId);
    await ref.read(selectedGroupIdProvider.notifier).select(null);
    if (context.mounted) context.go('/groups');
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
