import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/models/group.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../providers/groups_provider.dart';

class GroupSelectionScreen extends ConsumerWidget {
  const GroupSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(userGroupsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes espaces'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Mon profil',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (_) {
          final groups = ref.watch(orderedGroupsProvider);
          return _GroupList(
            groups: groups,
            onGroupTap: (group) async {
              await ref.read(selectedGroupIdProvider.notifier).select(group.id);
              if (context.mounted) context.go('/home');
            },
            onCreateTap: () => _showCreateSheet(context, ref),
            onJoinTap: () => _showJoinSheet(context, ref),
            onReorder: (oldIndex, newIndex) {
              var ids = groups.map((g) => g.id).toList();
              if (newIndex > oldIndex) newIndex--;
              final moved = ids.removeAt(oldIndex);
              ids.insert(newIndex, moved);
              ref.read(groupOrderProvider.notifier).reorder(ids);
            },
          );
        },
      ),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateGroupSheet(ref: ref),
    );
  }

  void _showJoinSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _JoinGroupSheet(ref: ref),
    );
  }
}

// ── Group list ───────────────────────────────────────────────────────────────

class _GroupList extends StatelessWidget {
  final List<Group> groups;
  final ValueChanged<Group> onGroupTap;
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;
  final void Function(int oldIndex, int newIndex) onReorder;

  const _GroupList({
    required this.groups,
    required this.onGroupTap,
    required this.onCreateTap,
    required this.onJoinTap,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_EmptyHint(onCreateTap: onCreateTap, onJoinTap: onJoinTap)],
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: onReorder,
            children: [
              for (var i = 0; i < groups.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey(groups[i].id),
                  index: i,
                  child: _GroupTile(
                    group: groups[i],
                    onTap: () => onGroupTap(groups[i]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCreateTap,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Créer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onJoinTap,
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: const Text('Rejoindre'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;

  const _GroupTile({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    group.emoji ?? group.name[0].toUpperCase(),
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: theme.textTheme.titleMedium),
                    if (group.description != null)
                      Text(
                        group.description!,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      '${group.memberIds.length} membre${group.memberIds.length > 1 ? 's' : ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (group.inviteCode != null)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: group.inviteCode!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Code ${group.inviteCode} copié !'),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      group.inviteCode!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onJoinTap;

  const _EmptyHint({required this.onCreateTap, required this.onJoinTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.people_outline,
                size: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text('Aucun espace', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Crée ou rejoins un espace partagé pour commencer.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Créer un espace'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onJoinTap,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Rejoindre avec un code'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create group sheet ────────────────────────────────────────────────────────

class _CreateGroupSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _CreateGroupSheet({required this.ref});

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedEmoji = '🏠';
  bool _loading = false;

  final _emojis = ['🏠', '👫', '👨‍👩‍👧‍👦', '🧑‍🤝‍🧑', '✈️', '🏖️', '🎓', '💼'];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;
    try {
      final freshUser = ref.read(authRepositoryProvider).currentUser ?? user;
      final userDoc = ref.read(userDocProvider).asData?.value;
      final effectivePhotoUrl = userDoc?['photoUrl'] as String? ?? freshUser.photoURL;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
      final group = await ref.read(groupsRepositoryProvider).createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        emoji: _selectedEmoji,
        userId: user.uid,
        displayName: freshUser.displayName ?? user.email ?? 'Membre',
        photoUrl: showPhoto ? effectivePhotoUrl : null,
        showProfilePhoto: showPhoto,
      );
      if (mounted) {
        await ref.read(selectedGroupIdProvider.notifier).select(group.id);
        if (mounted) {
          Navigator.of(context).pop();
          context.go('/home');
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nouvel espace', style: theme.textTheme.titleLarge),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _emojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final emoji = _emojis[i];
                  final selected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: "Nom de l'espace"),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 30,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Champ requis';
                if (v.trim().length > 30) return '30 caractères maximum';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optionnel)',
              ),
              maxLength: 150,
              maxLines: 2,
              validator: (v) {
                if (v != null && v.trim().length > 150) return '150 caractères maximum';
                return null;
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _create,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join group sheet ──────────────────────────────────────────────────────────

class _JoinGroupSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const _JoinGroupSheet({required this.ref});

  @override
  ConsumerState<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<_JoinGroupSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.length < 6) {
      setState(() => _error = 'Le code doit contenir 6 caractères.');
      return;
    }

    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final freshUser = ref.read(authRepositoryProvider).currentUser ?? user;
      final userDoc = ref.read(userDocProvider).asData?.value;
      final effectivePhotoUrl = userDoc?['photoUrl'] as String? ?? freshUser.photoURL;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
      final group = await ref.read(groupsRepositoryProvider).joinGroupByCode(
        code,
        user.uid,
        freshUser.displayName ?? user.email ?? 'Membre',
        photoUrl: showPhoto ? effectivePhotoUrl : null,
        showProfilePhoto: showPhoto,
      );

      if (!mounted) return;

      if (group == null) {
        setState(() => _error = 'Code invalide ou groupe introuvable.');
        return;
      }

      final userName = freshUser.displayName ?? user.email ?? 'Quelqu\'un';
      ref.read(messagesRepositoryProvider).sendSystemMessage(
        groupId: group.id,
        userId: user.uid,
        content: '👋 $userName a rejoint le groupe',
        notifScreen: 'chat',
      );

      await ref.read(selectedGroupIdProvider.notifier).select(group.id);
      if (mounted) {
        Navigator.of(context).pop();
        context.go('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Rejoindre un espace', style: theme.textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Entre le code partagé par un membre du groupe.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: "Code d'invitation",
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              errorText: _error,
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loading ? null : _join,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('Rejoindre'),
          ),
        ],
      ),
    );
  }
}
