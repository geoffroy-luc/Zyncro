import 'package:flutter/material.dart';

/// Balayage horizontal pour changer de mois : vers la gauche → mois suivant,
/// vers la droite → mois précédent (comme les flèches de l'en-tête).
///
/// Seule la fin d'un glissé assez rapide compte : un tap sur un jour et le
/// défilement vertical de l'écran ne sont pas affectés.
class MonthSwipeDetector extends StatelessWidget {
  const MonthSwipeDetector({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  /// Vitesse minimale (px/s) pour qu'un glissé change de mois.
  static const minVelocity = 250.0;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity <= -minVelocity) {
          onNext();
        } else if (velocity >= minVelocity) {
          onPrevious();
        }
      },
      child: child,
    );
  }
}

/// Grille du mois animée : la nouvelle grille glisse depuis le côté du
/// balayage ([step] = +1 mois suivant, -1 précédent).
class MonthSlideSwitcher extends StatelessWidget {
  const MonthSlideSwitcher({
    super.key,
    required this.month,
    required this.step,
    required this.child,
  });

  final DateTime month;
  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final current = ValueKey(month);
    return ClipRect(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previous) => Stack(
          alignment: Alignment.topCenter,
          children: [...previous, ?currentChild],
        ),
        transitionBuilder: (child, animation) {
          // Entrant : arrive du côté du balayage. Sortant (animation
          // inversée) : part du côté opposé.
          final incoming = child.key == current;
          final dx = (incoming ? step : -step).toDouble();
          return SlideTransition(
            position: Tween(
              begin: Offset(dx, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: KeyedSubtree(key: current, child: child),
      ),
    );
  }
}
