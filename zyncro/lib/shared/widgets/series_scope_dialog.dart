import 'package:flutter/material.dart';
import 'package:zyncro/design_system/context_extensions.dart';
import 'package:zyncro/shared/domain/recurrence/series_split.dart';

/// Choix de la portée d'une modification / suppression sur une occurrence
/// d'une série. `null` si l'utilisateur annule.
Future<SeriesScope?> showSeriesScopeDialog(
  BuildContext context, {
  required String title,
  required bool deleting,
}) {
  return showDialog<SeriesScope>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(context.l10n.seriesPorteeExplication),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.l10n.seriesAnnuler),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, SeriesScope.wholeSeries),
          child: Text(
            context.l10n.seriesToute,
            style: deleting ? TextStyle(color: context.colors.error) : null,
          ),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, SeriesScope.thisAndFollowing),
          child: Text(
            context.l10n.seriesCelleCiEtSuivantes,
            style: deleting ? TextStyle(color: context.colors.error) : null,
          ),
        ),
      ],
    ),
  );
}
