import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Returns a deterministic colour for a given user [uid].
/// The same uid always maps to the same colour, regardless of the screen.
Color avatarColorForUid(String uid) {
  const colors = [
    Color(0xFF4F7CFF), // Blue
    Color(0xFF2BB8A5), // Teal
    Color(0xFFFFB86B), // Orange
    Color(0xFFE85D75), // Pink
    Color(0xFF9B59B6), // Purple
    Color(0xFF27AE60), // Green
  ];
  return colors[uid.hashCode.abs() % colors.length];
}

/// Circular avatar : shows [photoUrl] when available and [showPhoto] is true,
/// otherwise shows the first 2 chars of [displayName] as initials.
///
/// The initials are always rendered underneath; the photo is layered on top so
/// initials are visible while the image is loading and act as a fallback if
/// the network request fails.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final bool showPhoto;
  final String displayName;
  final double radius;

  /// Accent colour for the initials circle background / text.
  /// Defaults to [AppColors.primary].
  final Color? color;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.showPhoto = true,
    required this.displayName,
    this.radius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.primary;
    final initials = _initials(displayName);
    final size = radius * 2;

    // Initials avatar – always the base layer.
    final initialsWidget = CircleAvatar(
      radius: radius,
      backgroundColor: accent.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );

    // No photo requested → plain initials.
    if (!showPhoto || photoUrl == null) return initialsWidget;

    // Photo + initials fallback via Stack.
    // The NetworkImage is layered on top; if it fails to load the initials
    // remain visible below.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          initialsWidget,
          ClipOval(
            child: Image.network(
              photoUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.length >= 2
        ? trimmed.substring(0, 2).toUpperCase()
        : trimmed[0].toUpperCase();
  }
}
