import 'package:flutter/material.dart';
import 'package:zyncro/core/error/failure.dart';
import 'package:zyncro/core/error/failure_mapper.dart';
import 'package:zyncro/design_system/context_extensions.dart';

// ── Error view ───────────────────────────────────────────────────────────────

class GroupsErrorView extends StatelessWidget {
  const GroupsErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isPermission = FailureMapper.from(error) is PermissionDeniedFailure;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPermission ? Icons.lock_outline : Icons.cloud_off_outlined,
              size: 56,
              color: context.colors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              isPermission
                  ? 'Impossible d\'accéder à tes espaces'
                  : 'Impossible de charger tes espaces',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPermission
                  ? 'Vérifie ta connexion, puis reconnecte-toi si le problème persiste.'
                  : 'Vérifie ta connexion internet, puis réessaie.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.groupsReessayer),
            ),
          ],
        ),
      ),
    );
  }
}
