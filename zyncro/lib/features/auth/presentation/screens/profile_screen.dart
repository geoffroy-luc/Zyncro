import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../providers/auth_provider.dart';

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
    _loadNotifPref();
  }

  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() =>
          _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true);
    }
  }

  // ── Pseudo ────────────────────────────────────────────────────────────────

  Future<void> _editPseudo() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final controller = TextEditingController(text: user?.displayName ?? '');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Modifier le pseudo'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Pseudo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      await ref.read(authRepositoryProvider).updateDisplayName(controller.text.trim());
      if (mounted) setState(() {});
    }
  }

  // ── Photo ─────────────────────────────────────────────────────────────────

  Future<void> _showPhotoOptions(
    String? customPhotoUrl,
    bool showProfilePhoto,
  ) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final hasProviderPhoto = (user?.photoURL ?? '').isNotEmpty;
    final hasCustomPhoto = (customPhotoUrl ?? '').isNotEmpty;

    await showModalBottomSheet(
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (hasProviderPhoto && hasCustomPhoto)
              ListTile(
                leading: const Icon(Icons.refresh_outlined),
                title: const Text('Réinitialiser avec la photo Google/Apple'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _resetToProviderPhoto();
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                showProfilePhoto
                    ? Icons.hide_image_outlined
                    : Icons.image_outlined,
                color: AppColors.textSecondary,
              ),
              title: Text(
                showProfilePhoto
                    ? 'Afficher uniquement mes initiales'
                    : 'Afficher ma photo de profil',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _toggleShowPhoto(!showProfilePhoto);
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $msg')),
        );
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null) {
      final messaging = FirebaseMessaging.instance;
      if (value) {
        final token = await messaging.getToken();
        if (token != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'fcmToken': token}, SetOptions(merge: true));
        }
      } else {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'fcmToken': null});
        } catch (_) {}
        await messaging.deleteToken();
      }
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
        title: const Text('Se déconnecter'),
        content: const Text('Confirmes-tu la déconnexion ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Déconnecter'),
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
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est irréversible. Ton compte et toutes tes données seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await ref.read(authRepositoryProvider).deleteAccount();
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : $e')),
          );
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch authStateProvider so the avatar refreshes if the Firebase Auth user changes.
    final user = ref.watch(authStateProvider).asData?.value
        ?? ref.read(authRepositoryProvider).currentUser;
    final userDoc = ref.watch(userDocProvider).asData?.value;

    final displayName = user?.displayName ?? user?.email ?? 'Utilisateur';
    final email = user?.email ?? '';

    // Custom photo (uploaded) or null → fall back to provider photo
    final customPhotoUrl = userDoc?['photoUrl'] as String?;
    final showProfilePhoto = userDoc?['showProfilePhoto'] as bool? ?? true;
    final effectivePhotoUrl = customPhotoUrl ?? user?.photoURL;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mon profil')),
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
                          color: AppColors.primary,
                        ),
                      )
                    : GestureDetector(
                        onTap: () => _showPhotoOptions(
                          customPhotoUrl,
                          showProfilePhoto,
                        ),
                        child: UserAvatar(
                          photoUrl: effectivePhotoUrl,
                          showPhoto: showProfilePhoto,
                          displayName: displayName,
                          radius: 44,
                        ),
                      ),
                if (!_loadingPhoto)
                  GestureDetector(
                    onTap: () => _showPhotoOptions(
                      customPhotoUrl,
                      showProfilePhoto,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
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
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 32),

          // ── Section : Infos ──────────────────────────────────────────────
          _SectionHeader(label: 'Informations'),
          _Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline, color: AppColors.primary),
              title: const Text('Pseudo'),
              subtitle: Text(displayName),
              trailing: IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onPressed: _editPseudo,
              ),
            ),
          ),

          // ── Section : Préférences ────────────────────────────────────────
          _SectionHeader(label: 'Préférences'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    showProfilePhoto
                        ? Icons.account_circle_outlined
                        : Icons.account_circle_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Afficher ma photo de profil'),
                  subtitle: Text(
                    showProfilePhoto
                        ? 'Les autres voient ta photo'
                        : 'Les autres voient tes initiales',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
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
                          activeThumbColor: AppColors.primary,
                        ),
                ),
                Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                ListTile(
                  leading: Icon(
                    _notificationsEnabled
                        ? Icons.notifications_outlined
                        : Icons.notifications_off_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Notifications'),
                  trailing: _loadingNotif
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeThumbColor: AppColors.primary,
                        ),
                ),
              ],
            ),
          ),

          // ── Section : Compte ─────────────────────────────────────────────
          _SectionHeader(label: 'Compte'),
          _Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.logout_outlined,
                      color: AppColors.textSecondary),
                  title: const Text('Se déconnecter'),
                  onTap: _signOut,
                ),
                Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppColors.border),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: AppColors.error),
                  title: const Text(
                    'Supprimer le compte',
                    style: TextStyle(color: AppColors.error),
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

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
