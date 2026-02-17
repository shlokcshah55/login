import 'package:flutter/material.dart';

class GavelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GavelButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FloatingActionButton(
        heroTag: "justDecideButton",
        onPressed: () {
          print('🎲 JUST DECIDE BUTTON TAPPED');
          onPressed();
        },
        backgroundColor: const Color.fromARGB(255, 68, 95, 12),
        child: const Icon(
          Icons.explore_rounded,
          size: 28.0,
          color: Colors.white,
        ),
        ),
      );
  }
}
