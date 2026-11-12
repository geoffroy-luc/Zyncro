import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zyncro/core/navigation/app_routes.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/features/auth/presentation/providers/auth_provider.dart';
import 'package:zyncro/features/auth/presentation/widgets/apple_icon.dart';
import 'package:zyncro/features/auth/presentation/widgets/google_icon.dart';
import 'package:zyncro/features/auth/presentation/widgets/guest_pseudo_sheet.dart';
import 'package:zyncro/features/auth/presentation/widgets/loading_type.dart';
import 'package:zyncro/features/auth/presentation/widgets/spinner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  LoadingType? _loadingType;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    _startLoading(LoadingType.email);
    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithEmail(
            _emailController.text.trim(),
            _passwordController.text,
          );
    } on FirebaseAuthException catch (e) {
      _setError(_mapEmailError(e.code));
    } finally {
      _stopLoading();
    }
  }

  Future<void> _signInWithGoogle() async {
    _startLoading(LoadingType.google);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'sign-in-cancelled') _setError('Connexion Google échouée.');
    } catch (_) {
      _setError('Connexion Google échouée.');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _signInWithApple() async {
    _startLoading(LoadingType.apple);
    try {
      await ref.read(authRepositoryProvider).signInWithApple();
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'Apple sign-in FirebaseAuthException: ${e.code} - ${e.message}',
      );
      if (e.code != 'sign-in-cancelled') _setError('Connexion Apple échouée.');
    } catch (e) {
      debugPrint('Apple sign-in error: $e');
      _setError('Connexion Apple échouée.');
    } finally {
      _stopLoading();
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Entre ton email pour réinitialiser le mot de passe.');
      return;
    }
    _startLoading(LoadingType.email);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.authEmailDeReinitialisationEnvoye),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        _setError('Aucun compte avec cet email.');
      } else {
        _setError('Erreur lors de l\'envoi.');
      }
    } finally {
      _stopLoading();
    }
  }

  void _showGuestPseudoSheet() {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => GuestPseudoSheet(
          onConfirm: (pseudo) {
            Navigator.of(context).pop();
            unawaited(_signInAnonymously(pseudo));
          },
        ),
      ),
    );
  }

  Future<void> _signInAnonymously(String pseudo) async {
    _startLoading(LoadingType.anonymous);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously(pseudo);
    } on FirebaseAuthException catch (_) {
      _setError('Connexion anonyme échouée.');
    } finally {
      _stopLoading();
    }
  }

  void _startLoading(LoadingType type) => setState(() {
    _loading = true;
    _loadingType = type;
    _error = null;
  });

  void _stopLoading() {
    if (mounted) {
      setState(() {
        _loading = false;
        _loadingType = null;
      });
    }
  }

  void _setError(String msg) {
    if (mounted) setState(() => _error = msg);
  }

  String _mapEmailError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect.';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessaie plus tard.';
      default:
        return 'Une erreur est survenue.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 64),
              Text(
                context.l10n.authZyncro,
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: context.colors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.authRetrouveTonEspacePartage,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 48),

              // ── Email / password form ──────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: context.l10n.authEmail,
                        prefixIcon: const Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => v == null || !v.contains('@')
                          ? 'Email invalide'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: context.l10n.authMotDePasse,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      validator: (v) => v == null || v.length < 6
                          ? 'Minimum 6 caractères'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.colors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.textSecondary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          context.l10n.authMotDePasseOublie,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loadingType == LoadingType.email
                          ? const Spinner()
                          : Text(context.l10n.authSeConnecter),
                    ),
                  ],
                ),
              ),

              // ── Divider ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: context.colors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        context.l10n.authOu,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    Expanded(child: Divider(color: context.colors.border)),
                  ],
                ),
              ),

              // ── Google ────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: _loadingType == LoadingType.google
                    ? Spinner(color: context.colors.primary)
                    : const GoogleIcon(),
                label: Text(context.l10n.authContinuerAvecGoogle),
              ),
              const SizedBox(height: 12),

              // ── Apple ──────────────────────────────────────────────
              if (Platform.isIOS) ...[
                OutlinedButton.icon(
                  onPressed: _loading ? null : _signInWithApple,
                  icon: _loadingType == LoadingType.apple
                      ? Spinner(color: context.colors.primary)
                      : const AppleIcon(),
                  label: Text(context.l10n.authContinuerAvecApple),
                ),
                const SizedBox(height: 12),
              ],

              // ── Anonyme ───────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _loading ? null : _showGuestPseudoSheet,
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  side: BorderSide(color: context.colors.border),
                ),
                icon: _loadingType == LoadingType.anonymous
                    ? Spinner(color: context.colors.textSecondary)
                    : const Icon(Icons.person_outline, size: 20),
                label: Text(context.l10n.authContinuerSansCompte),
              ),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go(AppRoutes.register),
                child: Text(context.l10n.authPasEncoreDeCompteS),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
