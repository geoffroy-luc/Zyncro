import 'package:flutter/painting.dart';

/// Couleurs d'identité des onglets, fixes quel que soit le thème (valeurs
/// historiques exactes). `Deep` = fin du dégradé de l'en-tête.
abstract final class TabPalette {
  static const home = Color(0xFF9B59B6);
  static const homeDeep = Color(0xFF7D3C98);
  static const calendar = Color(0xFF4F7CFF);
  static const calendarDeep = Color(0xFF315FEA);
  static const notes = Color(0xFF2BB8A5);
  static const notesDeep = Color(0xFF1A9B88);
  static const expenses = Color(0xFFFFB86B);
  static const expensesDeep = Color(0xFFF5A855);
  static const chat = Color(0xFFE85D75);
  static const chatDeep = Color(0xFFC94060);

  /// Par index d'onglet (ordre de `AppRoutes.shellTabs`).
  static const colors = [home, calendar, notes, expenses, chat];

  /// Dégradés par défaut des en-têtes, même ordre.
  static const gradients = [
    [home, homeDeep],
    [calendar, calendarDeep],
    [notes, notesDeep],
    [expenses, expensesDeep],
    [chat, chatDeep],
  ];
}

/// Soldes et remboursements (onglet Dépenses).
abstract final class BalancePalette {
  /// On vous doit / tout est réglé.
  static const positive = Color(0xFF2BB8A5);
  static const positiveDeep = Color(0xFF1E9B8A);

  /// Vous devez.
  static const negative = Color(0xFFFF6B6B);
  static const negativeDeep = Color(0xFFE85D75);

  /// Bouton « Rembourser ».
  static const settleAction = Color(0xFF4F7CFF);
}
