import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

Future<void> showExpandedCardTextSheet({
  required BuildContext context,
  required String title,
  required String text,
  String? eyebrow,
  String? meta,
  bool preserveEyebrowCase = false,
}) {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) return Future.value();
  final trimmedEyebrow = eyebrow?.trim();
  final eyebrowText = trimmedEyebrow == null || trimmedEyebrow.isEmpty
      ? null
      : preserveEyebrowCase
          ? trimmedEyebrow
          : trimmedEyebrow.toUpperCase();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final bottomInset = MediaQuery.of(context).padding.bottom;

      return SafeArea(
        top: false,
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.54,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4EDE6),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 32,
                        child: Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: PinitColors.creamDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(22, 2, 22, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (eyebrowText != null) ...[
                              Text(
                                eyebrowText,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.aubergineSoft,
                                  letterSpacing: 1.15,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(
                              title,
                              style: const TextStyle(
                                fontFamily: 'Rova',
                                fontSize: 32,
                                fontWeight: FontWeight.w100,
                                color: PinitColors.aubergine,
                                letterSpacing: 0.8,
                                height: 1.02,
                              ),
                            ),
                            if (meta != null && meta.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: PinitColors.creamSunk,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: PinitColors.creamDeep,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  meta.trim(),
                                  style: GoogleFonts.dmSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: PinitColors.mute,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            22,
                            0,
                            22,
                            24 + bottomInset,
                          ),
                          physics: const BouncingScrollPhysics(),
                          child: Text(
                            trimmedText,
                            style: GoogleFonts.dmSans(
                              fontSize: 15.5,
                              height: 1.48,
                              fontWeight: FontWeight.w500,
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
        ),
      );
    },
  );
}
