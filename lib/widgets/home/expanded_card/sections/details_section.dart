import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:login/models/locations.dart';
import 'package:login/pages/profile/widgets/pinit_colors.dart';
import 'package:url_launcher/url_launcher.dart';

/// "The essentials" — bordered list of utility rows: directions,
/// website, phone, today's hours, menu, services, amenities.
///
/// Stateless. Tap handlers for directions / website are passed in so
/// the parent can keep launch logic + error handling colocated with
/// other URL handling.
///
/// Style note: every row icon is rendered in aubergine on creamDeep,
/// per Style.MD ("Maximum three colours visible on any screen at
/// once"). The previous rainbow `color` per row violated this rule.
class DetailsSection extends StatelessWidget {
  const DetailsSection({
    super.key,
    required this.location,
    required this.onOpenInMaps,
    required this.onOpenWebsite,
  });

  final LocationModel location;
  final VoidCallback onOpenInMaps;
  final VoidCallback onOpenWebsite;

  @override
  Widget build(BuildContext context) {
    final items = <_DetailItem>[];

    // Google Maps
    if (location.googleMapsUri != null || location.lat != null) {
      items.add(_DetailItem(
        icon: Icons.map_rounded,
        label: 'Directions',
        value: 'Open in Google Maps',
        onTap: onOpenInMaps,
      ));
    }

    // Website
    if (location.website != null && location.website!.isNotEmpty) {
      final host =
          Uri.tryParse(location.website!)?.host ?? 'Visit website';
      items.add(_DetailItem(
        icon: Icons.language_rounded,
        label: 'Website',
        value: host,
        onTap: onOpenWebsite,
      ));
    }

    // Phone
    if (location.phoneNumber != null ||
        location.internationalPhoneNumber != null) {
      final phone =
          location.internationalPhoneNumber ?? location.phoneNumber ?? '';
      items.add(_DetailItem(
        icon: Icons.phone_rounded,
        label: 'Phone',
        value: phone,
        onTap: () async {
          final uri = Uri.parse('tel:$phone');
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
      ));
    }

    // Opening hours
    if (location.openingHoursText != null &&
        location.openingHoursText!.isNotEmpty) {
      // Find today's hours
      final now = DateTime.now();
      final weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final todayName = weekdays[now.weekday - 1];
      final todayHours = location.openingHoursText!.firstWhere(
        (h) => h.toLowerCase().contains(todayName.toLowerCase()),
        orElse: () => location.openingHoursText!.first,
      );
      items.add(_DetailItem(
        icon: Icons.schedule_rounded,
        label: 'Today',
        value: todayHours.replaceFirst(RegExp(r'^[A-Za-z]+:\s*'), ''),
      ));
    }

    // Menu
    if (location.menu != null && location.menu!.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.menu_book_rounded,
        label: 'Menu',
        value: 'View menu',
        onTap: () async {
          final uri = Uri.tryParse(location.menu!);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
      ));
    }

    // Service booleans as compact row
    final services = <String>[];
    if (location.servesBreakfast == true) services.add('Breakfast');
    if (location.servesBrunch == true) services.add('Brunch');
    if (location.servesLunch == true) services.add('Lunch');
    if (location.servesDinner == true) services.add('Dinner');
    if (location.servesCoffee == true) services.add('Coffee');
    if (location.servesCocktails == true) services.add('Cocktails');
    if (location.servesVegetarianFood == true) services.add('Veggie');
    if (services.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.dining_rounded,
        label: 'Serves',
        value: services.join(' · '),
      ));
    }

    // Amenities
    final amenities = <String>[];
    if (location.goodForGroups == true) amenities.add('Groups');
    if (location.goodForChildren == true) amenities.add('Kids');
    if (location.outdoorSeating == true) amenities.add('Outdoor');
    if (location.liveMusic == true) amenities.add('Live music');
    if (location.goodForWatchingSports == true) amenities.add('Sports');
    if (amenities.isNotEmpty) {
      items.add(_DetailItem(
        icon: Icons.verified_rounded,
        label: 'Good for',
        value: amenities.join(' · '),
      ));
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETAILS',
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: PinitColors.aubergineSoft,
            letterSpacing: 0.12 * 11,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'The essentials',
          style: TextStyle(
            fontFamily: 'Rova',
            fontSize: 28,
            fontWeight: FontWeight.w100,
            color: PinitColors.aubergine,
            letterSpacing: 1.3,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: PinitColors.creamSunk,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: PinitColors.creamDeep, width: 1.5),
          ),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return _DetailRow(item: item, showDivider: !isLast);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item, required this.showDivider});

  final _DetailItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PinitColors.creamDeep,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, size: 18, color: PinitColors.aubergine),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergineSoft,
                    letterSpacing: 0.12 * 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.value,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: PinitColors.aubergine,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (item.onTap != null)
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: PinitColors.aubergineSoft),
        ],
      ),
    );

    return Column(
      children: [
        item.onTap != null
            ? GestureDetector(
                onTap: item.onTap,
                behavior: HitTestBehavior.opaque,
                child: child,
              )
            : child,
        if (showDivider)
          const Padding(
            padding: EdgeInsets.only(left: 70, right: 18),
            child: Divider(height: 1, color: PinitColors.creamDeep),
          ),
      ],
    );
  }
}
