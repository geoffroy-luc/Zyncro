import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/chat/presentation/providers/messages_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

// ── Join group sheet ──────────────────────────────────────────────────────────

class JoinGroupSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const JoinGroupSheet({super.key, required this.ref});

  @override
  ConsumerState<JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends ConsumerState<JoinGroupSheet> {
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
      final effectivePhotoUrl =
          userDoc?['photoUrl'] as String? ?? freshUser.photoUrl;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
      final group = await ref
          .read(groupsRepositoryProvider)
          .joinGroupByCode(
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
      if (mounted) {
        Navigator.of(context).pop();
        context.go(AppRoutes.home);
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              Text(
                context.l10n.groupsRejoindreUnEspace,
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.groupsEntreLeCodePartagePar,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              labelText: context.l10n.groupsCodeDInvitation,
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
                : Text(context.l10n.groupsRejoindre),
          ),
        ],
      ),
    );
  }
}
