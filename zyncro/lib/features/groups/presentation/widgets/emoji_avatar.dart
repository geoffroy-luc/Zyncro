import 'package:flutter/material.dart';

/// Repli quand le groupe n'a pas de photo (ou qu'elle échoue à charger) :
/// emoji du groupe, sinon initiale du nom, sinon 👥.
class EmojiAvatar extends StatelessWidget {
  final String? emoji;
  final String? name;

  const EmojiAvatar({super.key, required this.emoji, required this.name});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        (emoji != null && emoji!.isNotEmpty)
            ? emoji!
            : ((name != null && name!.isNotEmpty)
                  ? name![0].toUpperCase()
                  : '👥'),
        style: const TextStyle(fontSize: 44),
      ),
    );
  }
}
