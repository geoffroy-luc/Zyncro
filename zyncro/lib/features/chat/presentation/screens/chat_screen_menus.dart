part of 'chat_screen.dart';

/// Boutons et menus radiaux du composer (« + », caméra).
mixin _ChatActionMenus on _ChatScreenStateBase {
  Widget _plusIconButton(BuildContext context) {
    return CompositedTransformTarget(
      link: _plusButtonLink,
      child: GestureDetector(
        onTap: () => setState(() {
          _showQuickActions = !_showQuickActions;
          if (_showQuickActions) _showCameraActions = false;
        }),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: _showQuickActions
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : context.colors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: _showQuickActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.border,
            ),
          ),
          child: AnimatedRotation(
            turns: _showQuickActions ? 0.125 : 0,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              Icons.add,
              color: _showQuickActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.textSecondary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // Menu radial : les options se déploient en quart de cercle au-dessus
  // et à droite du bouton "+" (0° = tout droit, 90° = complètement à droite),
  // ancré exactement sur le bouton via _plusButtonLink.
  Widget _quickActionsPopup(BuildContext context) {
    const radius = 62.0;
    const buttonSize = 40.0;
    // La popup est centrée (via CompositedTransformFollower.followerAnchor)
    // sur le bouton "+" ; boxCenter sert d'origine pour repositionner les
    // options qui, sinon, débordent d'une boîte 0x0 et ne reçoivent aucun tap
    // (le hit-test d'un Stack est borné par sa propre taille, même avec
    // clipBehavior: Clip.none qui ne fait que dessiner au-delà).
    const boxSize = 200.0;
    const boxCenter = boxSize / 2;

    Widget option({
      required IconData icon,
      required bool active,
      required VoidCallback onTap,
      required double angleDeg,
      required int index,
    }) {
      final angle = angleDeg * math.pi / 180;
      final dx = radius * math.sin(angle);
      final dy = -radius * math.cos(angle);
      return Positioned(
        left: boxCenter + dx - buttonSize / 2,
        top: boxCenter + dy - buttonSize / 2,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + index * 40),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: active
                    ? Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1)
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : context.colors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : context.colors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          option(
            icon: Icons.search,
            active: _showSearch,
            angleDeg: 15,
            index: 0,
            onTap: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) _search = '';
              _showQuickActions = false;
            }),
          ),
          option(
            icon: Icons.poll_outlined,
            active: false,
            angleDeg: 75,
            index: 1,
            onTap: () {
              setState(() => _showQuickActions = false);
              unawaited(_showCreatePoll());
            },
          ),
        ],
      ),
    );
  }

  Widget _cameraIconButton(BuildContext context) {
    return CompositedTransformTarget(
      link: _cameraButtonLink,
      child: GestureDetector(
        onTap: _isUploadingMedia
            ? null
            : () => setState(() {
                _showCameraActions = !_showCameraActions;
                if (_showCameraActions) _showQuickActions = false;
              }),
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(right: 8, bottom: 2),
          decoration: BoxDecoration(
            color: _showCameraActions
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : context.colors.background,
            shape: BoxShape.circle,
            border: Border.all(
              color: _showCameraActions
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.border,
            ),
          ),
          child: _isUploadingMedia
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colors.textSecondary,
                  ),
                )
              : AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  transitionBuilder: (child, anim) =>
                      RotationTransition(turns: anim, child: child),
                  child: Icon(
                    _showCameraActions
                        ? Icons.close
                        : Icons.camera_alt_outlined,
                    key: ValueKey(_showCameraActions),
                    color: _showCameraActions
                        ? Theme.of(context).colorScheme.primary
                        : context.colors.textSecondary,
                    size: 18,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _radialOptionButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: context.colors.textSecondary, size: 18),
      ),
    );
  }

  // Menu radial : les 3 options se déploient en quart de cercle au-dessus
  // et à droite du bouton photo (0° = tout droit, 90° = complètement à droite),
  // ancré exactement sur le bouton via _cameraButtonLink.
  Widget _cameraRadialMenu() {
    const radius = 62.0;
    const buttonSize = 40.0;
    // Voir le commentaire équivalent dans _quickActionsPopup : la popup est
    // centrée sur le bouton caméra via followerAnchor, et boxCenter sert
    // d'origine pour que les boutons restent dans la zone de hit-test.
    const boxSize = 200.0;
    const boxCenter = boxSize / 2;

    Widget option({
      required IconData icon,
      required VoidCallback? onTap,
      required double angleDeg,
      required int index,
    }) {
      final angle = angleDeg * math.pi / 180;
      final dx = radius * math.sin(angle);
      final dy = -radius * math.cos(angle);
      return Positioned(
        left: boxCenter + dx - buttonSize / 2,
        top: boxCenter + dy - buttonSize / 2,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 200 + index * 40),
          curve: Curves.easeOutBack,
          builder: (_, value, child) =>
              Transform.scale(scale: value, child: child),
          child: _radialOptionButton(icon: icon, onTap: onTap),
        ),
      );
    }

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          option(
            icon: Icons.camera_alt_outlined,
            angleDeg: 0,
            index: 0,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_captureFromCamera(video: false));
                  },
          ),
          option(
            icon: Icons.videocam_outlined,
            angleDeg: 45,
            index: 1,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_captureFromCamera(video: true));
                  },
          ),
          option(
            icon: Icons.photo_library_outlined,
            angleDeg: 90,
            index: 2,
            onTap: _isUploadingMedia
                ? null
                : () {
                    setState(() => _showCameraActions = false);
                    unawaited(_pickFromGallery());
                  },
          ),
        ],
      ),
    );
  }

  Widget _inputIconsCluster(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_plusIconButton(context), _cameraIconButton(context)],
    );
  }
}
