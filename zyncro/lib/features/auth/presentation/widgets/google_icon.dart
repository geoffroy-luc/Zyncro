import 'package:flutter/material.dart';

class GoogleIcon extends StatelessWidget {
  const GoogleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: const Text(
        'G',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4285F4),
          height: 1.3,
        ),
      ),
    );
  }
}
