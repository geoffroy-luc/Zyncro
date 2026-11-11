import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/domain/repositories/groups_repository.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/invite_link_provider.dart';
import 'package:zyncro/features/groups/presentation/widgets/invite_card.dart';
import 'package:zyncro/features/groups/presentation/widgets/join_link_invalid_link.dart';

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
          userDoc?['photoUrl'] as String? ?? freshUser.photoUrl;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;

      final group = await ref
          .read(groupsRepositoryProvider)
          .joinGroupByCode(
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
      unawaited(
        ref
            .read(messagesRepositoryProvider)
            .sendSystemMessage(
              groupId: group.id,
              userId: user.uid,
              content: '👋 $userName a rejoint le groupe',
              notifScreen: 'chat',
            ),
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
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: context.colors.textPrimary),
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
                  return JoinLinkInvalidLink(onClose: _close);
                }

                // Déjà membre ? (les groupes de l'utilisateur sont accessibles)
                final myGroups =
                    ref.watch(userGroupsProvider).asData?.value ?? [];
                final alreadyMember = myGroups.any(
                  (g) => g.id == preview.groupId,
                );

                return InviteCard(
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
