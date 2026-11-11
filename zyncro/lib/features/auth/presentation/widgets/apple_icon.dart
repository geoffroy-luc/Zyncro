import 'package:flutter/material.dart';

class AppleIcon extends StatelessWidget {
  const AppleIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: Icon(Icons.apple, size: 20, color: Colors.black),
    );
  }
}
