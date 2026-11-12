import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/groups/presentation/providers/groups_provider.dart';

// ── Create group sheet ────────────────────────────────────────────────────────

class CreateGroupSheet extends ConsumerStatefulWidget {
  final WidgetRef ref;

  const CreateGroupSheet({super.key, required this.ref});

  @override
  ConsumerState<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedEmoji = '🏠';
  bool _loading = false;

  final _emojis = [
    '🏠',
    '👫',
    '👨‍👩‍👧‍👦',
    '🧑‍🤝‍🧑',
    '✈️',
    '🏖️',
    '🎓',
    '💼',
  ];

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
      final effectivePhotoUrl =
          userDoc?['photoUrl'] as String? ?? freshUser.photoUrl;
      final showPhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
      final group = await ref
          .read(groupsRepositoryProvider)
          .createGroup(
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
          context.go(AppRoutes.home);
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.groupsNouvelEspace,
                  style: theme.textTheme.titleLarge,
                ),
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
                            ? context.colors.primary.withValues(alpha: 0.15)
                            : context.colors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(
                                color: context.colors.primary,
                                width: 2,
                              )
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
              decoration: InputDecoration(
                labelText: context.l10n.groupsNomDeLEspace,
              ),
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
              decoration: InputDecoration(
                labelText: context.l10n.groupsDescriptionOptionnel,
              ),
              maxLength: 150,
              maxLines: 2,
              validator: (v) {
                if (v != null && v.trim().length > 150) {
                  return '150 caractères maximum';
                }
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
                  : Text(context.l10n.groupsCreer),
            ),
          ],
        ),
      ),
    );
  }
}
