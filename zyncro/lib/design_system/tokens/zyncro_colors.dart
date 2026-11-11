import 'package:flutter/material.dart';

/// Couleurs SÉMANTIQUES de l'app, portées par le thème (ThemeExtension).
///
/// Les widgets lisent `context.colors.<rôle>` et jamais une valeur en dur :
/// c'est ce qui permettra le mode sombre (fournir [dark] et un ThemeMode).
/// [light] reprend EXACTEMENT les valeurs historiques (rendu identique).
@immutable
class ZyncroColors extends ThemeExtension<ZyncroColors> {
  const ZyncroColors({
    required this.primary,
    required this.primaryDark,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.error,
    required this.success,
    required this.shadow,
    required this.subtleSurface,
    required this.mutedSurface,
    required this.mediaBackground,
  });

  final Color primary;
  final Color primaryDark;
  final Color secondary;
  final Color accent;

  /// Fond des écrans.
  final Color background;

  /// Fond des cartes, feuilles, barres.
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color error;
  final Color success;

  /// Ombre légère des cartes.
  final Color shadow;

  /// Surfaces secondaires (puces, champs inactifs).
  final Color subtleSurface;
  final Color mutedSurface;

  /// Fond derrière les médias (vignettes vidéo, visionneuse).
  final Color mediaBackground;

  static const light = ZyncroColors(
    primary: Color(0xFF4F7CFF),
    primaryDark: Color(0xFF315FEA),
    secondary: Color(0xFF2BB8A5),
    accent: Color(0xFFFFB86B),
    background: Color(0xFFF7F9FC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    border: Color(0xFFE5E7EB),
    error: Color(0xFFEF4444),
    success: Color(0xFF27AE60),
    shadow: Color(0x0A000000),
    subtleSurface: Color(0xFFF3F4F6),
    mutedSurface: Color(0xFFF0F2F5),
    mediaBackground: Color(0xFF1C1C1E),
  );

  @override
  ZyncroColors copyWith({
    Color? primary,
    Color? primaryDark,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? error,
    Color? success,
    Color? shadow,
    Color? subtleSurface,
    Color? mutedSurface,
    Color? mediaBackground,
  }) {
    return ZyncroColors(
      primary: primary ?? this.primary,
      primaryDark: primaryDark ?? this.primaryDark,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      error: error ?? this.error,
      success: success ?? this.success,
      shadow: shadow ?? this.shadow,
      subtleSurface: subtleSurface ?? this.subtleSurface,
      mutedSurface: mutedSurface ?? this.mutedSurface,
      mediaBackground: mediaBackground ?? this.mediaBackground,
    );
  }

  @override
  ZyncroColors lerp(ZyncroColors? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return ZyncroColors(
      primary: l(primary, other.primary),
      primaryDark: l(primaryDark, other.primaryDark),
      secondary: l(secondary, other.secondary),
      accent: l(accent, other.accent),
      background: l(background, other.background),
      surface: l(surface, other.surface),
      textPrimary: l(textPrimary, other.textPrimary),
      textSecondary: l(textSecondary, other.textSecondary),
      border: l(border, other.border),
      error: l(error, other.error),
      success: l(success, other.success),
      shadow: l(shadow, other.shadow),
      subtleSurface: l(subtleSurface, other.subtleSurface),
      mutedSurface: l(mutedSurface, other.mutedSurface),
      mediaBackground: l(mediaBackground, other.mediaBackground),
    );
  }
}
