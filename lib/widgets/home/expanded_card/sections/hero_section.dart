import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';

/// Hero image carousel + glass status badges that anchors the top of the
/// expanded location card. Stateless — the parent owns photo index state.
class HeroSection extends StatelessWidget {
  const HeroSection({
    super.key,
    required this.height,
    required this.photos,
    required this.currentPhotoIndex,
    required this.onPhotoChanged,
    required this.accentColor,
    required this.openStatusLabel,
    required this.openStatusColor,
    required this.priceLabel,
    required this.isWavy,
  });

  final double height;
  final List<String> photos;
  final int currentPhotoIndex;
  final ValueChanged<int> onPhotoChanged;
  final Color accentColor;
  final String openStatusLabel;
  final Color openStatusColor;
  final String priceLabel;
  final bool isWavy;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: height,
          child: photos.isEmpty
              ? _EmptyHero(accentColor: accentColor)
              : PageView.builder(
                  itemCount: photos.length,
                  onPageChanged: onPhotoChanged,
                  itemBuilder: (_, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: photos[i],
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            _EmptyHero(accentColor: accentColor),
                        errorWidget: (_, __, ___) =>
                            _EmptyHero(accentColor: accentColor, isError: true),
                      ),
                      // Scrim gradient — darker at top for badges, lighter at bottom
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.45),
                                Colors.black.withValues(alpha: 0.05),
                                Colors.black.withValues(alpha: 0.20),
                              ],
                              stops: const [0.0, 0.45, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        // Photo dots
        if (photos.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(photos.length, (i) {
                final active = i == currentPhotoIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),

        // Badges overlay — top of hero
        Positioned(
          top: 28,
          left: 16,
          right: 60, // leave room for close button area
          child: Row(
            children: [
              _GlassBadge(
                label: openStatusLabel,
                dotColor: openStatusColor,
              ),
              if (priceLabel.isNotEmpty) ...[
                const SizedBox(width: 8),
                _GlassBadge(label: priceLabel),
              ],
              if (isWavy) ...[
                const SizedBox(width: 8),
                const _GlassBadge(
                  label: '✨ Wavy',
                  textColor: PinitColors.accent,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.accentColor, this.isError = false});

  final Color accentColor;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: 0.15),
            accentColor.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isError ? Icons.broken_image_outlined : Icons.restaurant_rounded,
          size: 48,
          color: accentColor.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _GlassBadge extends StatelessWidget {
  const _GlassBadge({
    required this.label,
    this.dotColor,
    this.textColor,
  });

  final String label;
  final Color? dotColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: PinitColors.aubergine.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: PinitColors.cream.withValues(alpha: 0.18), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Text(
                label.toUpperCase(),
                style: GoogleFonts.dmSans(
                  color: textColor ?? PinitColors.cream,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15 * 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The little 42px circular close button positioned in the top-right of
/// the card. Lives here so all hero-area chrome stays together.
class ExpandedCardCloseButton extends StatelessWidget {
  const ExpandedCardCloseButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: PinitColors.cream,
          shape: BoxShape.circle,
          border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          boxShadow: PinitColors.subtleShadow,
        ),
        child: const Icon(Icons.close_rounded,
            size: 20, color: PinitColors.aubergine),
      ),
    );
  }
}
