import 'package:flutter/material.dart';
import 'package:login/pages/home/widgets/home_action_pill_button.dart';

class SweetTreatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const SweetTreatButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HomeActionPillButton(
      label: 'sweet treat',
      icon: Icons.cake_rounded,
      gradientColors: const [
        Color(0xFFCC4B7A),
        Color(0xFFFF7AA9),
      ],
      foregroundColor: Colors.white,
      onPressed: () {
        print('🧁 SWEET TREAT BUTTON TAPPED');
        onPressed();
      },
    );
  }
}
