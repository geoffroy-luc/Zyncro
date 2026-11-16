import 'package:flutter/widgets.dart';

/// Fait défiler la **seule** liste [position] pour rendre [target] visible.
///
/// `Scrollable.ensureVisible` remonte tous les défileurs parents : dans les
/// onglets balayables (PageView horizontal), centrer un message à droite
/// décalait aussi la page d'onglet, coincée entre deux onglets.
Future<void> revealInScrollPosition(
  ScrollPosition position,
  BuildContext target, {
  double alignment = 0.5,
  Duration duration = Duration.zero,
  Curve curve = Curves.ease,
}) {
  final object = target.findRenderObject();
  if (object == null || !object.attached) return Future<void>.value();
  return position.ensureVisible(
    object,
    alignment: alignment,
    duration: duration,
    curve: curve,
  );
}
