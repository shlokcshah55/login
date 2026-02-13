import 'package:flutter/material.dart';

class SweetTreatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SweetTreatButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FloatingActionButton(
        heroTag: "sweetTreatButton",
        onPressed: () {
          print('🧁 SWEET TREAT BUTTON TAPPED');
          onPressed();
        },
        backgroundColor: Colors.pink.shade400,
        child: const Icon(
          Icons.cake_rounded,
          size: 28.0,
          color: Colors.white,
        ),
        ),
    );
  }
}