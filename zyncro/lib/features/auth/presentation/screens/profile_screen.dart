import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:zyncro/core/notifications/notification_providers.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/auth/presentation/widgets/profile_card.dart';
import 'package:zyncro/features/auth/presentation/widgets/profile_section_header.dart';
import 'package:zyncro/shared/widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _notificationsEnabled = true;
  bool _loadingNotif = false;
  bool _loadingPhoto = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNotifPref());
  }

  Future<void> _loadNotifPref() async {
    final enabled = await ref.read(notificationPreferencesProvider).isEnabled();
    if (mounted) setState(() => _notificationsEnabled = enabled);
  }

  // ── Pseudo ────────────────────────────────────────────────────────────────

  Future<void> _editPseudo() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final controller = TextEditingController(text: user?.displayName ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.authModifierLePseudo),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: context.l10n.authPseudo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.authAnnuler),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.authEnregistrer),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(authRepositoryProvider)
          .updateDisplayName(controller.text.trim());
      if (mounted) setState(() {});
    }
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _showPhotoOptions(
    String? customPhotoUrl,
    bool showProfilePhoto,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final hasProviderPhoto = (user?.photoUrl ?? '').isNotEmpty;
    final hasCustomPhoto = (customPhotoUrl ?? '').isNotEmpty;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.l10n.authPrendreUnePhoto),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_pickPhoto(ImageSource.camera));
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.l10n.authChoisirDepuisLaGalerie),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_pickPhoto(ImageSource.gallery));
              },
            ),
            if (hasProviderPhoto && hasCustomPhoto)
              ListTile(
                leading: const Icon(Icons.refresh_outlined),
                title: Text(context.l10n.authReinitialiserAvecLaPhotoGoogle),
                onTap: () {
                  Navigator.of(ctx).pop();
                  unawaited(_resetToProviderPhoto());
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                showProfilePhoto
                    ? Icons.hide_image_outlined
                    : Icons.image_outlined,
                color: context.colors.textSecondary,
              ),
              title: Text(
                showProfilePhoto
                    ? 'Afficher uniquement mes initiales'
                    : 'Afficher ma photo de profil',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                unawaited(_toggleShowPhoto(!showProfilePhoto));
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _loadingPhoto = true);
    try {
      await ref.read(userProfileServiceProvider).uploadPhoto(source);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('cancelled')) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.authErreur(msg))));
      }
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _resetToProviderPhoto() async {
    setState(() => _loadingPhoto = true);
    try {
      await ref.read(userProfileServiceProvider).resetToProviderPhoto();
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  Future<void> _toggleShowPhoto(bool show) async {
    setState(() => _loadingPhoto = true);
    try {
      await ref.read(userProfileServiceProvider).updateShowProfilePhoto(show);
    } finally {
      if (mounted) setState(() => _loadingPhoto = false);
    }
  }

  // ── Notifications ─────────────────────────────────────────────────────────

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _loadingNotif = true);
    await ref.read(notificationPreferencesProvider).setEnabled(value);

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      await ref
          .read(pushNotificationServiceProvider)
          .setEnabledForUser(user.uid, enabled: value);
    }

    if (mounted) {
      setState(() {
        _notificationsEnabled = value;
        _loadingNotif = false;
      });
    }
  }

  // ── Sign out / delete ─────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.authSeDeconnecter),
        content: Text(context.l10n.authConfirmesTuLaDeconnexion),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.authAnnuler),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.authDeconnecter),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.authSupprimerLeCompte),
        content: Text(context.l10n.authCetteActionEstIrreversibleTon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.authAnnuler),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.l10n.authSupprimer,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount();
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.authErreur(e))));
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch authStateProvider so the avatar refreshes if the Firebase Auth user changes.
    final user =
        ref.watch(authStateProvider).asData?.value ??
        ref.read(authRepositoryProvider).currentUser;
    final userDoc = ref.watch(userDocProvider).asData?.value;

    final displayName = user?.displayName ?? user?.email ?? 'Utilisateur';
    final email = user?.email ?? '';

    // Custom photo (uploaded) or null → fall back to provider photo
    final customPhotoUrl = userDoc?['photoUrl'] as String?;
    final showProfilePhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
    final effectivePhotoUrl = customPhotoUrl ?? user?.photoUrl;

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: Text(context.l10n.authMonProfil)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                _loadingPhoto
                    ? SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.primary,
                        ),
                      )
                    : GestureDetector(
                        onTap: () =>
                            _showPhotoOptions(customPhotoUrl, showProfilePhoto),
                        child: UserAvatar(
                          photoUrl: effectivePhotoUrl,
                          showPhoto: showProfilePhoto,
                          displayName: displayName,
                          radius: 44,
                        ),
                      ),
                if (!_loadingPhoto)
                  GestureDetector(
                    onTap: () =>
                        _showPhotoOptions(customPhotoUrl, showProfilePhoto),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (email.isNotEmpty)
            Center(
              child: Text(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 32),

          // ── Section : Infos ──────────────────────────────────────────────
          ProfileSectionHeader(label: context.l10n.authInformations),
          ProfileCard(
            child: ListTile(
              leading: Icon(
                Icons.person_outline,
                color: context.colors.primary,
              ),
              title: Text(context.l10n.authPseudo),
              subtitle: Text(displayName),
              trailing: IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: context.colors.textSecondary,
                ),
                onPressed: _editPseudo,
              ),
            ),
          ),

          // ── Section : Préférences ────────────────────────────────────────
          ProfileSectionHeader(label: context.l10n.authPreferences),
          ProfileCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    showProfilePhoto
                        ? Icons.account_circle_outlined
                        : Icons.account_circle_outlined,
                    color: context.colors.primary,
                  ),
                  title: Text(context.l10n.authAfficherMaPhotoDeProfil),
                  subtitle: Text(
                    showProfilePhoto
                        ? 'Les autres voient ta photo'
                        : 'Les autres voient tes initiales',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                  trailing: _loadingPhoto
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: showProfilePhoto,
                          onChanged: _toggleShowPhoto,
                          activeThumbColor: context.colors.primary,
                        ),
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.colors.border,
                ),
                ListTile(
                  leading: Icon(
                    _notificationsEnabled
                        ? Icons.notifications_outlined
                        : Icons.notifications_off_outlined,
                    color: context.colors.primary,
                  ),
                  title: Text(context.l10n.authNotifications),
                  trailing: _loadingNotif
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeThumbColor: context.colors.primary,
                        ),
                ),
              ],
            ),
          ),

          // ── Section : Compte ─────────────────────────────────────────────
          ProfileSectionHeader(label: context.l10n.authCompte),
          ProfileCard(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.logout_outlined,
                    color: context.colors.textSecondary,
                  ),
                  title: Text(context.l10n.authSeDeconnecter),
                  onTap: _signOut,
                ),
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: context.colors.border,
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: context.colors.error,
                  ),
                  title: Text(
                    context.l10n.authSupprimerLeCompte,
                    style: TextStyle(color: context.colors.error),
                  ),
                  onTap: _deleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
