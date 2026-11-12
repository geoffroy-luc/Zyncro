import 'package:flutter/material.dart';
import 'package:zyncro/design_system/tokens/zyncro_colors.dart';
import 'package:zyncro/l10n/generated/app_localizations.dart';

extension DesignSystemContext on BuildContext {
  /// Couleurs sémantiques du thème courant.
  ZyncroColors get colors =>
      Theme.of(this).extension<ZyncroColors>() ?? ZyncroColors.light;

  /// Textes traduits (lib/l10n/app_fr.arb).
  AppLocalizations get l10n => AppLocalizations.of(this);

  /// Styles de texte du thème courant.
  TextTheme get textStyles => Theme.of(this).textTheme;
}
