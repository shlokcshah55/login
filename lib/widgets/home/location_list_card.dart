import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:login/widgets/home/expanded_location_card.dart';

/// Shared image-left restaurant row used by carousel list views and social
/// review. Optional source/status labels let callers add context without
/// changing the familiar restaurant-card hierarchy.
class LocationListCard extends StatefulWidget {
  const LocationListCard({
    super.key,
    required this.location,
    this.onTap,
    this.sourceLabel,
    this.statusLabel,
    this.statusIcon,
    this.borderColor,
  });

  final LocationModel location;
  final VoidCallback? onTap;
  final String? sourceLabel;
  final String? statusLabel;
  final IconData? statusIcon;
  final Color? borderColor;

  @override
  State<LocationListCard> createState() => _LocationListCardState();
}

class _LocationListCardState extends State<LocationListCard> {
  bool _pressed = false;

  LocationModel get location => widget.location;

  Color get _borderColor =>
      widget.borderColor ??
      ((location.vibe?.wavyScore ?? 0) > 0.45
          ? PinitColors.accent
          : PinitColors.aubergine);

  void _open() {
    final onTap = widget.onTap;
    if (onTap != null) {
      onTap();
      return;
    }
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, _, __) => ExpandedLocationCard(
        location: location,
        onClose: () => Navigator.of(ctx).pop(),
      ),
      transitionBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cuisine = location.displayCuisine;
    final summary = _summaryText;
    final source = widget.sourceLabel ?? _defaultSourceLabel;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _open,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 110,
          decoration: BoxDecoration(
            color: PinitColors.cream,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _borderColor,
                blurRadius: 0,
                offset: const Offset(4, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 120,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _RestaurantImage(location: location),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00000000), Color(0x33000000)],
                            stops: [0.55, 1],
                          ),
                        ),
                      ),
                      if (location.emoji?.isNotEmpty == true)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PinitColors.cream,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: PinitColors.aubergine,
                                width: 1.4,
                              ),
                            ),
                            child: Text(
                              location.emoji!,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(width: 1.5, color: _borderColor),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: PinitColors.creamSunk,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.statusIcon ?? FeatherIcons.mapPin,
                              size: 11,
                              color: PinitColors.mute,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                source,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: PinitColors.mute,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            if (widget.statusLabel != null)
                              _StatusPill(label: widget.statusLabel!)
                            else if (location.rating != null)
                              _Rating(rating: location.rating!),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: PinitColors.aubergine,
                                  height: 1.15,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 3),
                              if (summary != null)
                                Text(
                                  summary,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    color: PinitColors.mute,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                              const Spacer(),
                              Row(
                                children: [
                                  if (location.priceLevel != null &&
                                      location.priceLevel! > 0)
                                    _Tag(label: '£' * location.priceLevel!),
                                  if (cuisine != null)
                                    Flexible(child: _Tag(label: cuisine)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _defaultSourceLabel {
    if (location.preference == LocationPreference.saved) return 'SAVED';
    if (location.preference == LocationPreference.recommended) {
      return 'TOP PICK';
    }
    if (location.preference == LocationPreference.bubble) return 'BUBBLE PICK';
    if (location.preference == LocationPreference.search) return 'MATCH';
    return location.displayCuisine?.toUpperCase() ?? 'NEARBY';
  }

  String? get _summaryText {
    final values = [
      location.generatedSummary,
      location.editorialSummary,
      location.recommendedDishes == null
          ? null
          : 'Try: ${location.recommendedDishes}',
      location.vicinity,
    ];
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }
}

class _RestaurantImage extends StatelessWidget {
  const _RestaurantImage({required this.location});

  final LocationModel location;

  @override
  Widget build(BuildContext context) {
    final url = location.imageUrl ?? location.photoReference;
    if (url == null || url.isEmpty) {
      return Container(
        color: PinitColors.creamSunk,
        alignment: Alignment.center,
        child:
            Text(location.emoji ?? '📍', style: const TextStyle(fontSize: 40)),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: PinitColors.creamSunk),
      errorWidget: (_, __, ___) => Container(
        color: PinitColors.creamSunk,
        alignment: Alignment.center,
        child: const Icon(FeatherIcons.image, color: PinitColors.mute),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(FeatherIcons.star, size: 12, color: PinitColors.aubergine),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: PinitColors.aubergine,
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: PinitColors.creamSunk,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PinitColors.creamDeep),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.dmSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: PinitColors.aubergine,
        ),
      ),
    );
  }
}
