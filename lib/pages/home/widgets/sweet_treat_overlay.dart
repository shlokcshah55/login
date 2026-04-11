import 'package:flutter/material.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/themes/app_typography.dart';

class SweetTreatOverlay extends StatelessWidget {
  final VoidCallback onClose;
  final ValueChanged<String> onSubmit;

  const SweetTreatOverlay({
    Key? key,
    required this.onClose,
    required this.onSubmit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: PinitColors.aubergine.withValues(alpha: 0.18),
            ),
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 360),
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
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: PinitColors.accent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
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
                              'SWEET TREAT',
                              style: AppTypography.sans(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: PinitColors.aubergineSoft,
                                letterSpacing: 1.32,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dessert first.',
                              style: AppTypography.brand(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
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
                  const SizedBox(height: 14),
                  Text(
                    'We will search for pastries, puddings, ice cream, and late-night sugar hits around you.',
                    style: AppTypography.sans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: PinitColors.aubergineSoft,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: PinitColors.creamSunk,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: PinitColors.creamDeep,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Search prompt: "Places with desserts or sweets that are currently open"',
                      style: AppTypography.sans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: PinitColors.aubergine,
                        height: 1.35,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: PinitColors.aubergine,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () {
                            onSubmit(
                              'Places with desserts or sweets that are currently open',
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'FIND SWEET SPOTS',
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
      ],
    );
  }
}
