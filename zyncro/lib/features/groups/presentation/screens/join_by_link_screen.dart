import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../chat/presentation/providers/messages_provider.dart';
import '../../domain/repositories/i_groups_repository.dart';
import '../providers/groups_provider.dart';
import '../providers/invite_link_provider.dart';

/// Écran de confirmation affiché lorsqu'un lien d'invitation est ouvert.
/// Résout le code → aperçu du groupe → propose de rejoindre.
class JoinByLinkScreen extends ConsumerStatefulWidget {
  final String code;
  const JoinByLinkScreen({super.key, required this.code});

  @override
  ConsumerState<JoinByLinkScreen> createState() => _JoinByLinkScreenState();
}

class _JoinByLinkScreenState extends ConsumerState<JoinByLinkScreen> {
  late Future<InvitePreview?> _previewFuture;
  bool _joining = false;
  bool _cleared = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _previewFuture = ref
        .read(groupsRepositoryProvider)
        .resolveInviteCode(widget.code);
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/groups');
    }
  }

  Future<void> _openExisting(String groupId) async {
    await ref.read(selectedGroupIdProvider.notifier).select(groupId);
    if (mounted) context.go('/home');
  }

  Future<void> _join(InvitePreview preview) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) return;

    setState(() {
      _joining = true;
      _error = null;
    });

    try {
      final freshUser = ref.read(authRepositoryProvider).currentUser ?? user;
      final userDoc = ref.read(userDocProvider).asData?.value;
      final effectivePhotoUrl =
          userDoc?['photoUrl'] as String? ?? freshUser.photoURL;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;

      final group = await ref.read(groupsRepositoryProvider).joinGroupByCode(
            widget.code,
            user.uid,
            freshUser.displayName ?? user.email ?? 'Membre',
            photoUrl: showPhoto ? effectivePhotoUrl : null,
            showProfilePhoto: showPhoto,
          );

      if (!mounted) return;

      if (group == null) {
        setState(() {
          _joining = false;
          _error = 'Ce lien d\'invitation est invalide ou a expiré.';
        });
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
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // On n'efface le code en attente qu'une fois l'utilisateur bien connecté et
    // l'écran affiché : effacer plus tôt (pendant le chargement de l'auth) le
    // perdrait si l'utilisateur doit d'abord se connecter.
    final loggedIn = ref.watch(authStateProvider).asData?.value != null;
    if (loggedIn && !_cleared) {
      _cleared = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(inviteLinkProvider.notifier).clear();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: _close,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FutureBuilder<InvitePreview?>(
              future: _previewFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  );
                }

                final preview = snapshot.data;
                if (snapshot.hasError || preview == null) {
                  return _InvalidLink(onClose: _close);
                }

                // Déjà membre ? (les groupes de l'utilisateur sont accessibles)
                final myGroups =
                    ref.watch(userGroupsProvider).asData?.value ?? [];
                final alreadyMember =
                    myGroups.any((g) => g.id == preview.groupId);

                return _InviteCard(
                  preview: preview,
                  alreadyMember: alreadyMember,
                  joining: _joining,
                  error: _error,
                  onJoin: () => _join(preview),
                  onOpen: () => _openExisting(preview.groupId),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final InvitePreview preview;
  final bool alreadyMember;
  final bool joining;
  final String? error;
  final VoidCallback onJoin;
  final VoidCallback onOpen;

  const _InviteCard({
    required this.preview,
    required this.alreadyMember,
    required this.joining,
    required this.error,
    required this.onJoin,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = preview.groupName;
    final emoji = preview.groupEmoji;
    final photoUrl = preview.groupPhotoUrl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: (photoUrl != null && photoUrl.isNotEmpty)
              ? Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _EmojiAvatar(
                    emoji: emoji,
                    name: name,
                  ),
                )
              : _EmojiAvatar(emoji: emoji, name: name),
        ),
        const SizedBox(height: 24),
        Text(
          alreadyMember
              ? 'Tu fais déjà partie de'
              : 'Tu as été invité·e à rejoindre',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          name?.isNotEmpty == true ? name! : 'un espace Zyncro',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        if (error != null) ...[
          Text(
            error!,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
        SizedBox(
          width: double.infinity,
          child: alreadyMember
              ? ElevatedButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.login),
                  label: const Text('Ouvrir cet espace'),
                )
              : ElevatedButton(
                  onPressed: joining ? null : onJoin,
                  child: joining
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
        ),
      ],
    );
  }
}

/// Repli quand le groupe n'a pas de photo (ou qu'elle échoue à charger) :
/// emoji du groupe, sinon initiale du nom, sinon 👥.
class _EmojiAvatar extends StatelessWidget {
  final String? emoji;
  final String? name;

  const _EmojiAvatar({required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        (emoji != null && emoji!.isNotEmpty)
            ? emoji!
            : ((name != null && name!.isNotEmpty)
                  ? name![0].toUpperCase()
                  : '👥'),
        style: const TextStyle(fontSize: 44),
      ),
    );
  }
}

class _InvalidLink extends StatelessWidget {
  final VoidCallback onClose;
  const _InvalidLink({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.link_off_rounded,
          size: 64,
          color: AppColors.textSecondary,
        ),
        const SizedBox(height: 20),
        Text(
          'Lien invalide',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Ce lien d\'invitation est invalide ou a expiré. Demande un nouveau '
          'lien à un membre du groupe.',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onClose,
            child: const Text('Fermer'),
          ),
        ),
      ],
    );
  }
}
