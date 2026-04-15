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
                : _buildList(),
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

  Widget _buildList() {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          itemCount: recommendations.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) return _buildHeader();
            final loc = recommendations[index - 1];
            return _TopPlaceRow(
              location: loc,
              added: wizardState.addedLocationIds.contains(loc.locationId),
              beenTo: wizardState.beenToLocationIds.contains(loc.locationId),
              onSave: () => wizardState.toggleAddedLocation(loc.locationId),
              onBeenTo: () => wizardState.toggleBeenToLocation(loc.locationId),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top places for you',
            style: TextStyle(
              fontFamily: 'Rova',
              fontSize: 28,
              fontWeight: FontWeight.w100,
              color: PinitColors.aubergine,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Save the ones you like. Mark the ones you\'ve already been to.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: PinitColors.mute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Consumer<SignupWizardState>(
      builder: (context, wizardState, _) {
        final addedCount = wizardState.addedLocationIds.length;
        final beenToCount = wizardState.beenToLocationIds.length;

        return Container(
          padding: const EdgeInsets.all(20),
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
              if (addedCount > 0 || beenToCount > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '$addedCount saved · $beenToCount been to',
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
                              (addedCount > 0 || beenToCount > 0)
                                  ? 'Finish'
                                  : 'Skip for now',
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

class _TopPlaceRow extends StatelessWidget {
  final LocationModel location;
  final bool added;
  final bool beenTo;
  final VoidCallback onSave;
  final VoidCallback onBeenTo;

  const _TopPlaceRow({
    required this.location,
    required this.added,
    required this.beenTo,
    required this.onSave,
    required this.onBeenTo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PinitColors.cream,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: added ? PinitColors.aubergine : PinitColors.creamDeep,
          width: added ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: PinitColors.aubergine.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(17),
              topRight: Radius.circular(17),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildImage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: PinitColors.aubergine,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (location.rating != null) ...[
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: PinitColors.accent,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        location.rating!.toStringAsFixed(1),
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: PinitColors.aubergine,
                        ),
                      ),
                    ],
                    if (location.cuisine != null &&
                        location.cuisine!.isNotEmpty) ...[
                      if (location.rating != null)
                        Text(
                          '  ·  ',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: PinitColors.mute,
                          ),
                        ),
                      Flexible(
                        child: Text(
                          location.cuisine!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: PinitColors.mute,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: added ? 'Saved' : 'Save',
                        icon: added
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        filled: added,
                        onTap: onSave,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        label: beenTo ? 'Been here' : 'Been here?',
                        icon: beenTo
                            ? Icons.place_rounded
                            : Icons.place_outlined,
                        filled: beenTo,
                        onTap: onBeenTo,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            size: 40,
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
            size: 40,
            color: PinitColors.mute,
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? PinitColors.aubergine : PinitColors.cream,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: PinitColors.aubergine,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: filled ? PinitColors.cream : PinitColors.aubergine,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: filled ? PinitColors.cream : PinitColors.aubergine,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
