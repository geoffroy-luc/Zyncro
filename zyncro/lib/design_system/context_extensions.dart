import 'package:flutter/material.dart';
import 'package:zyncro/design_system/tokens/zyncro_colors.dart';

extension DesignSystemContext on BuildContext {
  /// Couleurs sémantiques du thème courant.
  ZyncroColors get colors =>
      Theme.of(this).extension<ZyncroColors>() ?? ZyncroColors.light;

  /// Styles de texte du thème courant.
  TextTheme get textStyles => Theme.of(this).textTheme;
}
