import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

class FeatureIntroOverlay extends StatelessWidget {
  const FeatureIntroOverlay({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.primaryLabel,
    required this.illustrationPath,
    required this.icon,
    required this.onClose,
    required this.onPrimaryTap,
    this.iconBackgroundColor = PinitColors.aubergine,
    this.primaryColor = PinitColors.aubergine,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String primaryLabel;
  final String illustrationPath;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback onPrimaryTap;
  final Color iconBackgroundColor;
  final Color primaryColor;

  static Future<void> show(
    BuildContext context, {
    required String eyebrow,
    required String title,
    required String description,
    required String primaryLabel,
    required String illustrationPath,
    required IconData icon,
    required VoidCallback onPrimaryTap,
    Color iconBackgroundColor = PinitColors.aubergine,
    Color primaryColor = PinitColors.aubergine,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: PinitColors.aubergine.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogContext, _, __) => FeatureIntroOverlay(
        eyebrow: eyebrow,
        title: title,
        description: description,
        primaryLabel: primaryLabel,
        illustrationPath: illustrationPath,
        icon: icon,
        iconBackgroundColor: iconBackgroundColor,
        primaryColor: primaryColor,
        onClose: () => Navigator.of(dialogContext).pop(),
        onPrimaryTap: () {
          Navigator.of(dialogContext).pop();
          onPrimaryTap();
        },
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Container(
              decoration: BoxDecoration(
                color: PinitColors.cream,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: PinitColors.creamDeep,
                  width: 1.5,
                ),
                boxShadow: PinitColors.elevatedShadow,
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                minimum: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: PinitColors.creamDeep,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: PinitColors.cream,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                eyebrow,
                                style: AppTypography.sans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: PinitColors.aubergineSoft,
                                  letterSpacing: 1.32,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                style: AppTypography.brand(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w100,
                                  color: PinitColors.aubergine,
                                  letterSpacing: 0.3,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: onClose,
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: PinitColors.creamSunk,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: PinitColors.creamDeep,
                                width: 1.5,
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: PinitColors.aubergine,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: SizedBox(
                        height: 148,
                        child: SvgPicture.asset(
                          illustrationPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      description,
                      style: AppTypography.sans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: PinitColors.aubergineSoft,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: PinitColors.aubergine,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: PinitColors.aubergine,
                              blurRadius: 0,
                              offset: Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: onPrimaryTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  primaryLabel,
                                  style: AppTypography.sans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: PinitColors.cream,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
