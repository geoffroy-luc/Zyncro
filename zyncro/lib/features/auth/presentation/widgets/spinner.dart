import 'package:flutter/material.dart';

class Spinner extends StatelessWidget {
  final Color color;
  const Spinner({super.key, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(color: color, strokeWidth: 2),
    );
  }
}
