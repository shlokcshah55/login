import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../models/locations.dart';
import '../../../models/signup_wizard_state.dart';
import '../../profile/widgets/pinit_colors.dart';

class TopPlacesStep extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onComplete;
  final bool isCompleting;
  final List<LocationModel> recommendations;

  const TopPlacesStep({
    super.key,
    required this.onBack,
    required this.onComplete,
    required this.isCompleting,
    required this.recommendations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: recommendations.isEmpty
                ? _buildEmptyState()
                : _buildGrid(),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off_outlined,
              size: 48,
              color: PinitColors.mute,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load places right now",
              style: GoogleFonts.dmSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: PinitColors.aubergine,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You can skip for now and add favourites later.",
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: PinitColors.mute,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'Tap to add a few favourites',
                style: TextStyle(
                  fontFamily: 'Rova',
                  fontSize: 28,
                  fontWeight: FontWeight.w100,
                  color: PinitColors.aubergine,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hit the pin if you\'ve already been.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: PinitColors.mute,
                ),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegate(),
                itemCount: recommendations.length,
                itemBuilder: (context, index) {
                  final loc = recommendations[index];
                  final added = wizardState.addedLocationIds.contains(loc.locationId);
                  final beenTo = wizardState.beenToLocationIds.contains(loc.locationId);
                  return _TopPlaceCard(
                    location: loc,
                    added: added,
                    beenTo: beenTo,
                    onTap: () => wizardState.toggleAddedLocation(loc.locationId),
                    onBeenToTap: () => wizardState.toggleBeenToLocation(loc.locationId),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        final addedCount = wizardState.addedLocationIds.length;
        final beenToCount = wizardState.beenToLocationIds.length;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: PinitColors.cream,
            boxShadow: [
              BoxShadow(
                color: PinitColors.aubergine.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              if (addedCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$addedCount added · $beenToCount been to',
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: PinitColors.aubergine,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isCompleting ? null : onBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(
                          color: PinitColors.aubergine,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        'Back',
                        style: GoogleFonts.dmSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isCompleting ? null : onComplete,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: PinitColors.aubergine,
                        foregroundColor: PinitColors.cream,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: isCompleting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      PinitColors.cream,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Finishing up...',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              addedCount > 0 ? 'Continue' : 'Skip for now',
                              style: GoogleFonts.dmSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class SliverGridDelegate extends SliverGridDelegateWithFixedCrossAxisCount {
  const SliverGridDelegate()
      : super(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        );
}

class _TopPlaceCard extends StatelessWidget {
  final LocationModel location;
  final bool added;
  final bool beenTo;
  final VoidCallback onTap;
  final VoidCallback onBeenToTap;

  const _TopPlaceCard({
    required this.location,
    required this.added,
    required this.beenTo,
    required this.onTap,
    required this.onBeenToTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: added ? PinitColors.aubergine : PinitColors.creamDeep,
            width: added ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: PinitColors.aubergine.withValues(alpha: added ? 0.12 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildImage(),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        PinitColors.aubergine.withValues(alpha: 0.85),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      location.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: PinitColors.cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (location.rating != null) ...[
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: PinitColors.cream,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            location.rating!.toStringAsFixed(1),
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: PinitColors.cream,
                            ),
                          ),
                        ],
                        if (location.cuisine != null &&
                            location.cuisine!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '· ${location.cuisine}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: PinitColors.cream.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (added)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: PinitColors.aubergine,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: PinitColors.cream,
                    ),
                  ),
                ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: onBeenToTap,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: beenTo
                          ? PinitColors.accent
                          : PinitColors.cream.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          beenTo ? Icons.place : Icons.place_outlined,
                          size: 12,
                          color: PinitColors.aubergine,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          beenTo ? 'Been' : 'Been?',
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: PinitColors.aubergine,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final url = location.imageUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: PinitColors.creamDeep,
        child: const Center(
          child: Icon(
            Icons.restaurant,
            size: 32,
            color: PinitColors.mute,
          ),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: PinitColors.creamDeep,
        child: const Center(
          child: Icon(
            Icons.restaurant,
            size: 32,
            color: PinitColors.mute,
          ),
        ),
      ),
    );
  }
}
