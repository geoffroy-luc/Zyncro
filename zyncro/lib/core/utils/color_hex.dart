import 'package:flutter/painting.dart';

/// Conversions couleur ↔ hexadécimal (`#RRGGBB`), format stocké dans Firestore
/// (couleurs d'onglet, d'événement, de note, de catégorie, fond du chat).

/// `#RRGGBB` → [Color] opaque. Lève une [FormatException] si [hex] est invalide.
Color hexToColor(String hex) =>
    Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

/// Comme [hexToColor], mais renvoie `null` si [hex] est absent ou invalide.
Color? tryHexToColor(String? hex) {
  if (hex == null) return null;
  try {
    return hexToColor(hex);
  } on FormatException {
    return null;
  }
}

/// [Color] → `#RRGGBB` (majuscules, sans alpha).
String colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Variante plus sombre (luminosité HSL − [amount]) : bas des dégradés
/// d'onglet, bulles du chat, etc.
Color darken(Color color, [double amount = 0.12]) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
