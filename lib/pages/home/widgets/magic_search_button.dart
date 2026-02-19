import 'package:flutter/material.dart';
import 'package:login/pages/home/widgets/home_action_pill_button.dart';

class MagicSearchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MagicSearchButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return HomeActionPillButton(
      label: 'magic search',
      icon: Icons.auto_awesome_rounded,
      gradientColors: const [
        Color(0xFF6C3FB4),
        Color(0xFF8E66DF),
      ],
      foregroundColor: Colors.white,
      onPressed: () {
        print('🔮 MAGIC SEARCH BUTTON TAPPED');
        onPressed();
      },
    );
  }
}
