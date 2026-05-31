import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

Future<void> showExpandedCardTextSheet({
  required BuildContext context,
  required String title,
  required String text,
  String? eyebrow,
  String? meta,
}) {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) return Future.value();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return SafeArea(
        top: false,
        child: FractionallySizedBox(
          heightFactor: 0.72,
          alignment: Alignment.bottomCenter,
          child: Container(
            decoration: const BoxDecoration(
              color: PinitColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10, bottom: 18),
                    decoration: BoxDecoration(
                      color: PinitColors.creamDeep,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null && eyebrow.trim().isNotEmpty) ...[
                        Text(
                          eyebrow.trim().toUpperCase(),
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergineSoft,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                      ],
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Rova',
                          fontSize: 28,
                          fontWeight: FontWeight.w100,
                          color: PinitColors.aubergine,
                          letterSpacing: 1.1,
                          height: 1.05,
                        ),
                      ),
                      if (meta != null && meta.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          meta.trim(),
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: PinitColors.mute,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      trimmedText,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        height: 1.55,
                        fontWeight: FontWeight.w400,
                        color: PinitColors.aubergine,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
