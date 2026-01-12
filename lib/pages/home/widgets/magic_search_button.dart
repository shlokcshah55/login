import 'package:flutter/material.dart';
import 'package:login/themes/app_colors.dart';

class MagicSearchButton extends StatelessWidget {
  final VoidCallback onPressed;

  const MagicSearchButton({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FloatingActionButton(
        heroTag: "magicButton",
        onPressed: onPressed,
        backgroundColor: AppColors.secondary,
        child: const Icon(
          Icons.auto_awesome,
          size: 28.0,
          color: AppColors.onSecondary,
        ),
      ),
    );
  }
}
