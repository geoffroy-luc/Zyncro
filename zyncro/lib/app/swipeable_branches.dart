import 'dart:async';

import 'package:flutter/material.dart';

/// Conteneur des onglets du shell : on passe d'un onglet à l'autre en
/// balayant vers la gauche / la droite, la page suit le doigt.
///
/// Chaque onglet garde son état (défilement, saisie…) comme avec l'ancien
/// `IndexedStack`. Les gestes horizontaux internes (grille du calendrier,
/// onglets Dépenses / Équilibre, glisser pour répondre dans le chat) restent
/// prioritaires ; une liste horizontale interne arrivée à son bord passe le
/// relais aux onglets (Équilibre → Chat, Dépenses → Notes).
class SwipeableBranches extends StatefulWidget {
  const SwipeableBranches({
    super.key,
    required this.currentIndex,
    required this.onSwipeTo,
    required this.children,
  });

  /// Onglet affiché (source de vérité : le router).
  final int currentIndex;

  /// Appelé quand un balayage amène sur un autre onglet.
  final ValueChanged<int> onSwipeTo;

  /// Navigators des branches, dans l'ordre des onglets.
  final List<Widget> children;

  @override
  State<SwipeableBranches> createState() => _SwipeableBranchesState();
}

class _SwipeableBranchesState extends State<SwipeableBranches> {
  late final PageController _controller;

  /// Dernier onglet connu des deux côtés : évite que le changement venu du
  /// balayage revienne en écho comme un saut de page, et inversement.
  /// Initialisé dans initState (un `late` paresseux serait lu pour la
  /// première fois dans didUpdateWidget, avec le NOUVEL index).
  late int _shown;

  @override
  void initState() {
    super.initState();
    _shown = widget.currentIndex;
    _controller = PageController(initialPage: _shown);
  }

  @override
  void didUpdateWidget(SwipeableBranches oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changement venu d'ailleurs (barre d'onglets, notification, lien) :
    // saut direct, comme avant.
    if (widget.currentIndex != _shown) {
      _shown = widget.currentIndex;
      if (_controller.hasClients) _controller.jumpToPage(_shown);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Un balayage horizontal interne (onglets Dépenses / Équilibre…) arrivé
  /// en bout de course est en train de déplacer les onglets.
  bool _handingOff = false;

  /// Onglet de départ du relais : on ne s'en éloigne que d'un onglet.
  int _handoffFrom = 0;

  /// Passage de relais : quand une liste horizontale interne est à son bord
  /// et que le doigt continue, l'excédent fait glisser les onglets (au plus
  /// d'un onglet) ; au lâcher, on se cale sur l'onglet voisin ou on revient,
  /// selon la vitesse et la distance.
  bool _onInnerScroll(ScrollNotification n) {
    if (n.depth == 0 || n.metrics.axis != Axis.horizontal) return false;
    if (!_controller.hasClients) return false;
    final position = _controller.position;
    final pageWidth = position.viewportDimension;
    if (n is OverscrollNotification && n.dragDetails != null) {
      if (!_handingOff) {
        _handingOff = true;
        _handoffFrom = (_controller.page ?? _shown.toDouble()).round();
      }
      final min = (_handoffFrom - 1) * pageWidth;
      final max = (_handoffFrom + 1) * pageWidth;
      position.jumpTo(
        (position.pixels + n.overscroll)
            .clamp(min, max)
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    } else if (n is ScrollEndNotification && _handingOff) {
      _handingOff = false;
      final page = _controller.page ?? _handoffFrom.toDouble();
      final delta = page - _handoffFrom;
      final velocity = n.dragDetails?.primaryVelocity ?? 0;
      final int target;
      if (velocity < -_flingVelocity && delta > 0) {
        target = _handoffFrom + 1; // doigt vers la gauche : onglet suivant
      } else if (velocity > _flingVelocity && delta < 0) {
        target = _handoffFrom - 1; // doigt vers la droite : onglet précédent
      } else {
        target = delta.abs() >= 0.5
            ? _handoffFrom + delta.sign.toInt()
            : _handoffFrom;
      }
      unawaited(
        _controller.animateToPage(
          target.clamp(0, widget.children.length - 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    return false;
  }

  static const _flingVelocity = 300.0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onInnerScroll,
      child: _buildPages(),
    );
  }

  Widget _buildPages() {
    return PageView(
      controller: _controller,
      onPageChanged: (index) {
        if (index == _shown) return;
        setState(() => _shown = index);
        widget.onSwipeTo(index);
      },
      children: [
        for (final (index, child) in widget.children.indexed)
          // Onglets hors écran : animations en pause (comme l'ancien
          // IndexedStack), pour la batterie.
          TickerMode(
            enabled: index == _shown,
            child: _KeepAlive(child: child),
          ),
      ],
    );
  }
}

/// Garde l'onglet en mémoire hors écran (état conservé).
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
