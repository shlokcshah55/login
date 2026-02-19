import 'package:flutter/material.dart';
import 'package:login/pages/home/widgets/home_action_pill_button.dart';

class GavelButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GavelButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HomeActionPillButton(
      label: 'just decide',
      icon: Icons.gavel_rounded,
      gradientColors: const [
        Color(0xFF3E5D20),
        Color(0xFF6A8A3A),
      ],
      foregroundColor: Colors.white,
      onPressed: () {
        print('🎲 JUST DECIDE BUTTON TAPPED');
        onPressed();
      },
    );
  }
}
