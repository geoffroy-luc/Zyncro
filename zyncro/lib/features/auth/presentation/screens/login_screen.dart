import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

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
  _LoadingType? _loadingType;
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
    _startLoading(_LoadingType.email);
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(
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
    _startLoading(_LoadingType.google);
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

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _setError('Entre ton email pour réinitialiser le mot de passe.');
      return;
    }
    _startLoading(_LoadingType.email);
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de réinitialisation envoyé !')),
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

  Future<void> _signInAnonymously() async {
    _startLoading(_LoadingType.anonymous);
    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
    } on FirebaseAuthException catch (_) {
      _setError('Connexion anonyme échouée.');
    } finally {
      _stopLoading();
    }
  }

  void _startLoading(_LoadingType type) => setState(() {
    _loading = true;
    _loadingType = type;
    _error = null;
  });

  void _stopLoading() {
    if (mounted) setState(() { _loading = false; _loadingType = null; });
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
                'Zyncro',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text('Retrouve ton espace partagé', style: theme.textTheme.bodyMedium),
              const SizedBox(height: 48),

              // ── Email / password form ──────────────────────────────
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          v == null || !v.contains('@') ? 'Email invalide' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
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
                      validator: (v) =>
                          v == null || v.length < 6 ? 'Minimum 6 caractères' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _resetPassword,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _signIn,
                      child: _loadingType == _LoadingType.email
                          ? const _Spinner()
                          : const Text('Se connecter'),
                    ),
                  ],
                ),
              ),

              // ── Divider ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'ou',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
              ),

              // ── Google ────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _loading ? null : _signInWithGoogle,
                icon: _loadingType == _LoadingType.google
                    ? const _Spinner(color: AppColors.primary)
                    : const _GoogleIcon(),
                label: const Text('Continuer avec Google'),
              ),
              const SizedBox(height: 12),

              // ── Anonyme ───────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _loading ? null : _signInAnonymously,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                ),
                icon: _loadingType == _LoadingType.anonymous
                    ? const _Spinner(color: AppColors.textSecondary)
                    : const Icon(Icons.person_outline, size: 20),
                label: const Text('Continuer sans compte'),
              ),

              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/register'),
                child: const Text("Pas encore de compte ? S'inscrire"),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LoadingType { email, google, anonymous }

class _Spinner extends StatelessWidget {
  final Color color;
  const _Spinner({this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(color: color, strokeWidth: 2),
    );
  }
}

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.3,
        ),
      ),
    );
  }
}
